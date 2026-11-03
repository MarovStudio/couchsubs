// SPDX-License-Identifier: AGPL-3.0-only

using System.ComponentModel;
using System.Diagnostics;
using System.Net.Sockets;
using System.Text.RegularExpressions;

namespace CouchSubs.Core.LgTv;

public sealed record CommandResult(int Status, string Output);

/// <summary>Dış komut çalıştıran her şey (gerçekte <see cref="ProcessRunner"/>).</summary>
public interface ICommandRunner
{
    Task<CommandResult> RunAsync(string executable, IReadOnlyList<string> arguments, string? inputFile);
}

public enum DevModeError { Unreachable, KeyServerOff, WrongPassphrase, KeyRefused, InstallFailed, ToolMissing }

public sealed class DevModeException(DevModeError error) : Exception(error.ToString())
{
    public DevModeError Error { get; } = error;
}

/// <summary>ssh ve ssh-keygen'in yerleri.</summary>
public sealed record DevModeTools(string Ssh, string SshKeygen, string NullDevice)
{
    public static DevModeTools ForThisSystem() => OperatingSystem.IsWindows()
        ? new(Path.Combine(Environment.SystemDirectory, "OpenSSH", "ssh.exe"),
              Path.Combine(Environment.SystemDirectory, "OpenSSH", "ssh-keygen.exe"), "NUL")
        : new("/usr/bin/ssh", "/usr/bin/ssh-keygen", "/dev/null");
}

/// <summary>
/// TV uygulamasını LG'nin geliştirici modu üzerinden kurar ve günceller.
/// Geliştirici modu açık TV 9922 portunda SSH bekler; anahtar Key Server'dan bir kez alınır.
/// </summary>
public sealed class DevModeInstaller(string host, string keyFile, ICommandRunner runner, DevModeTools tools,
                                     TimeSpan? pollInterval = null, TimeSpan? installTimeout = null)
{
    public const int Port = 9922;
    private const string AppInfoPath = "/media/developer/apps/usr/palm/applications/com.couchsubs.tv/appinfo.json";
    private const string RemotePackage = "/media/developer/temp/couchsubs.ipk";

    /// <summary><c>com.couchsubs.tv_0.6.1_all.ipk</c> → <c>0.6.1</c></summary>
    public static string? VersionOfPackage(string name)
    {
        var parts = name.Split('_');
        return name.EndsWith(".ipk", StringComparison.Ordinal) && parts.Length >= 3 ? parts[1] : null;
    }

    public static bool IsNewer(string a, string b) =>
        Version.TryParse(a, out var left) && Version.TryParse(b, out var right) && left > right;

    public static string? VersionFromAppInfo(string text)
    {
        var match = Regex.Match(text, "\"version\"\\s*:\\s*\"([^\"]+)\"");
        return match.Success ? match.Groups[1].Value : null;
    }

    /// <summary>TV'de geliştirici modu açık mı? Kapalıysa port yanıt vermez.</summary>
    public static async Task<bool> IsDevModeOnAsync(string host, TimeSpan? timeout = null)
    {
        using var client = new TcpClient();
        using var cancellation = new CancellationTokenSource(timeout ?? TimeSpan.FromSeconds(2));
        try
        {
            await client.ConnectAsync(host, Port, cancellation.Token);
            return true;
        }
        catch (Exception)
        {
            return false;
        }
    }

    public static Uri KeyUrl(string host) => new($"http://{host}:9991/webos_rsa");

    /// <summary>Key Server'dan anahtarı alır ve TV ekranındaki parolayla çözer.</summary>
    public static async Task<string> FetchKeyAsync(string host, string passphrase, ICommandRunner runner, DevModeTools tools)
    {
        byte[] key;
        try
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
            key = await http.GetByteArrayAsync(KeyUrl(host));
        }
        catch (Exception)
        {
            throw new DevModeException(DevModeError.KeyServerOff);
        }
        var file = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        try
        {
            await File.WriteAllBytesAsync(file, key);
            var result = await runner.RunAsync(tools.SshKeygen, ["-q", "-p", "-P", passphrase, "-N", "", "-f", file], null);
            if (result.Status != 0) throw new DevModeException(DevModeError.WrongPassphrase);
            return await File.ReadAllTextAsync(file);
        }
        finally
        {
            File.Delete(file);
        }
    }

    /// <summary>TV'deki sürüm; uygulama kurulu değilse null.</summary>
    public async Task<string?> InstalledVersionAsync()
    {
        var result = await SshAsync($"cat {AppInfoPath}");
        return VersionFromAppInfo(result.Output);
    }

    /// <summary>Paketi TV'ye yükler, kurulumu başlatır ve TV'de istenen sürüm görünene kadar bekler.</summary>
    public async Task InstallAsync(string package, string version)
    {
        var upload = await SshAsync($"mkdir -p /media/developer/temp && cat > {RemotePackage}", package);
        if (upload.Status != 0) throw new DevModeException(DevModeError.InstallFailed);

        var parameters = $"{{\"id\":\"com.ares.defaultName\",\"ipkUrl\":\"{RemotePackage}\",\"subscribe\":true}}";
        // -n 1: ilk yanıttan sonra çıkar; kurulum TV'de sürer.
        await SshAsync($"/usr/bin/luna-send-pub -n 1 'luna://com.webos.appInstallService/dev/install' '{parameters}'");

        var timer = Stopwatch.StartNew();
        var limit = installTimeout ?? TimeSpan.FromSeconds(90);
        var installed = false;
        while (timer.Elapsed < limit)
        {
            if (await InstalledVersionAsync() == version)
            {
                installed = true;
                break;
            }
            await Task.Delay(pollInterval ?? TimeSpan.FromSeconds(2));
        }
        try { await SshAsync($"rm -f {RemotePackage}"); } catch (DevModeException) { /* geçici dosya kalabilir */ }
        if (!installed) throw new DevModeException(DevModeError.InstallFailed);
    }

    private async Task<CommandResult> SshAsync(string command, string? input = null)
    {
        var result = await runner.RunAsync(tools.Ssh,
        [
            "-p", Port.ToString(), "-i", keyFile,
            "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes", "-o", "ConnectTimeout=6", "-o", "LogLevel=ERROR",
            // TV'nin anahtarı her fabrika ayarında değişir ve eski türdedir.
            "-o", "StrictHostKeyChecking=no", "-o", $"UserKnownHostsFile={tools.NullDevice}",
            "-o", "HostKeyAlgorithms=+ssh-rsa", "-o", "PubkeyAcceptedAlgorithms=+ssh-rsa",
            $"prisoner@{host}", command,
        ], input);
        if (result.Status == 255)
            throw new DevModeException(result.Output.Contains("Permission denied", StringComparison.Ordinal)
                ? DevModeError.KeyRefused : DevModeError.Unreachable);
        return result;
    }
}

/// <summary>Komutları <see cref="Process"/> ile çalıştırır; pencere açmaz.</summary>
public sealed class ProcessRunner : ICommandRunner
{
    public async Task<CommandResult> RunAsync(string executable, IReadOnlyList<string> arguments, string? inputFile)
    {
        var start = new ProcessStartInfo(executable)
        {
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        foreach (var argument in arguments) start.ArgumentList.Add(argument);

        using var process = new Process { StartInfo = start };
        try
        {
            process.Start();
        }
        catch (Win32Exception)
        {
            // Windows'un OpenSSH istemcisi kaldırılmış olabilir.
            throw new DevModeException(DevModeError.ToolMissing);
        }
        var output = process.StandardOutput.ReadToEndAsync();
        var error = process.StandardError.ReadToEndAsync();
        if (inputFile is not null)
        {
            await using var input = File.OpenRead(inputFile);
            await input.CopyToAsync(process.StandardInput.BaseStream);
        }
        process.StandardInput.Close();
        await process.WaitForExitAsync();
        return new CommandResult(process.ExitCode, await output + await error);
    }
}
