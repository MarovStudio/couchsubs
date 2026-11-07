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

/// <summary>TV uygulamasını kurarken çıkan sorunlar (LG, Samsung ve Android TV ortak).</summary>
public enum DevModeError
{
    Unreachable, KeyServerOff, WrongPassphrase, KeyRefused, InstallFailed, ToolMissing,
    /// <summary>Samsung: TV Tizen 5.0'dan (2019) eski.</summary>
    TooOld,
    /// <summary>Samsung hesabıyla giriş tamamlanmadı.</summary>
    SignInFailed,
    /// <summary>Samsung TV'ye özel sertifikayı vermedi.</summary>
    CertificateFailed,
    /// <summary>Android: TV'de hata ayıklama izni verilmedi.</summary>
    NotApproved,
}

/// <param name="detail">Sorunu bulmak için ayrıntı (komut çıktısı gibi); hata günlüğüne yazılır, kullanıcıya gösterilmez.</param>
public sealed class DevModeException(DevModeError error, string? detail = null)
    : Exception(detail is null ? error.ToString() : $"{error}: {detail}")
{
    public DevModeError Error { get; } = error;
}

/// <summary>Key Server'dan gelen anahtarın parolasını çözen ssh-keygen'in yeri.</summary>
public sealed record DevModeTools(string SshKeygen)
{
    public static DevModeTools ForThisSystem() => OperatingSystem.IsWindows()
        ? new(Path.Combine(Environment.SystemDirectory, "OpenSSH", "ssh-keygen.exe"))
        : new("/usr/bin/ssh-keygen");
}

/// <summary>
/// TV uygulamasını LG'nin geliştirici modu üzerinden kurar ve günceller.
/// Geliştirici modu açık TV 9922 portunda SSH bekler; anahtar Key Server'dan bir kez alınır.
/// </summary>
public sealed class DevModeInstaller(IRemoteShell shell, TimeSpan? pollInterval = null, TimeSpan? installTimeout = null)
{
    /// <summary>TV'ye uygulamanın içinden SSH ile bağlanan kurucu.</summary>
    public static DevModeInstaller ForTv(string host, string keyFile) => new(new SshNetShell(host, Port, keyFile));

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
        if (upload.Status != 0)
            throw new DevModeException(DevModeError.InstallFailed, $"yükleme çıkış kodu {upload.Status}: {Short(upload.Output)}");
        // Paket TV'ye eksiksiz ulaştı mı? (wc yoksa ya da çıktı okunamazsa denetim atlanır.)
        var expected = new FileInfo(package).Length;
        var size = await SshAsync($"wc -c < {RemotePackage}");
        if (long.TryParse(size.Output.Trim(), out var actual) && actual != expected)
            throw new DevModeException(DevModeError.InstallFailed, $"paket TV'ye eksik ya da bozuk ulaştı: {actual}/{expected} bayt");

        var parameters = $"{{\"id\":\"com.ares.defaultName\",\"ipkUrl\":\"{RemotePackage}\",\"subscribe\":true}}";
        // -n 1: ilk yanıttan sonra çıkar; kurulum TV'de sürer.
        var response = await SshAsync($"/usr/bin/luna-send-pub -n 1 'luna://com.webos.appInstallService/dev/install' '{parameters}'");

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
        if (!installed)
            throw new DevModeException(DevModeError.InstallFailed,
                $"TV'de {version} sürümü görünmedi; kurulum yanıtı ({response.Status}): {Short(response.Output)}");
    }

    private static string Short(string text) => text.Length <= 500 ? text.Trim() : text[..500].Trim() + "…";

    private const string SessionTokenPath = "/var/luna/preferences/devmode_enabled";
    public static Uri RenewUrl(string token) => new($"https://developer.lge.com/secure/ResetDevModeSession.dev?sessionToken={Uri.EscapeDataString(token)}");
    public static Uri CheckUrl(string token) => new($"https://developer.lge.com/secure/CheckDevModeSession.dev?sessionToken={Uri.EscapeDataString(token)}");

    /// <summary>
    /// Geliştirici modunun 1000 saatlik süresini baştan başlatır (TV'deki Developer Mode uygulamasının EXTEND düğmesi
    /// gibi). Oturum jetonu TV'den okunur ve LG'nin sunucusuna gönderilir; webOS Homebrew'un dev-manager-desktop
    /// aracının yaptığının aynısı. Başarısız olursa yalnız uyarı döner: süre dolmadan kullanıcı TV'den de uzatabilir.
    /// </summary>
    /// <returns>Kalan süre (saat); bilinmiyorsa null.</returns>
    public async Task<int?> RenewSessionAsync(HttpClient http)
    {
        var token = (await SshAsync($"cat {SessionTokenPath}")).Output.Trim();
        if (token.Length == 0 || token.Contains(' ')) return null;
        try
        {
            var renewed = await http.GetStringAsync(RenewUrl(token));
            if (!renewed.Contains("success", StringComparison.OrdinalIgnoreCase)) return null;
            return RemainingHours(await http.GetStringAsync(CheckUrl(token)));
        }
        catch (Exception error) when (error is HttpRequestException or TaskCanceledException)
        {
            return null;
        }
    }

    /// <summary>LG'nin yanıtındaki kalan süre <c>999:58:40</c> (saat:dakika:saniye) biçimindedir.</summary>
    public static int? RemainingHours(string response)
    {
        var match = Regex.Match(response, @"(\d{1,4}):(\d{2}):(\d{2})");
        return match.Success ? int.Parse(match.Groups[1].Value) : null;
    }

    private Task<CommandResult> SshAsync(string command, string? input = null) => shell.RunAsync(command, input);
}

/// <summary>Komutları <see cref="Process"/> ile çalıştırır; pencere açmaz.</summary>
public sealed class ProcessRunner : ICommandRunner
{
    public async Task<CommandResult> RunAsync(string executable, IReadOnlyList<string> arguments, string? inputFile)
    {
        var start = new ProcessStartInfo(executable)
        {
            RedirectStandardInput = inputFile is not null,
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
            // Windows'un OpenSSH istemcisi (ssh-keygen) kaldırılmış olabilir.
            throw new DevModeException(DevModeError.ToolMissing);
        }
        var output = process.StandardOutput.ReadToEndAsync();
        var error = process.StandardError.ReadToEndAsync();
        if (inputFile is not null)
        {
            await using (var input = File.OpenRead(inputFile))
                await input.CopyToAsync(process.StandardInput.BaseStream);
            process.StandardInput.Close();
        }
        await process.WaitForExitAsync();
        return new CommandResult(process.ExitCode, await output + await error);
    }
}
