// SPDX-License-Identifier: AGPL-3.0-only

using CouchSubs.Core.LgTv;
using Xunit;

namespace CouchSubs.Core.Tests;

public class DevModeInstallerTests
{
    private sealed class FakeRunner : ICommandRunner
    {
        public List<(string Executable, IReadOnlyList<string> Arguments, string? Input)> Calls { get; } = [];
        public Func<string, CommandResult?> Answer { get; set; } = _ => null;
        public Task<CommandResult> RunAsync(string executable, IReadOnlyList<string> arguments, string? inputFile)
        {
            Calls.Add((executable, arguments, inputFile));
            return Task.FromResult(Answer(string.Join(' ', arguments)) ?? new CommandResult(0, ""));
        }
    }

    private static readonly DevModeTools Tools = new("ssh", "ssh-keygen", "NUL");

    private static DevModeInstaller Installer(FakeRunner runner) =>
        new("192.168.1.230", "key", runner, Tools, TimeSpan.FromMilliseconds(1), TimeSpan.FromMilliseconds(200));

    [Fact]
    public void VersionIsReadFromThePackageName()
    {
        Assert.Equal("0.6.1", DevModeInstaller.VersionOfPackage("com.couchsubs.tv_0.6.1_all.ipk"));
        Assert.Null(DevModeInstaller.VersionOfPackage("notes.txt"));
    }

    [Fact]
    public void RemainingSessionTimeIsReadFromLgsReply()
    {
        Assert.Equal(999, DevModeInstaller.RemainingHours("{\"result\":\"success\",\"errorCode\":\"200\",\"errorMsg\":\"999:58:40\"}"));
        Assert.Null(DevModeInstaller.RemainingHours("{\"result\":\"fail\"}"));
        Assert.Equal("https://developer.lge.com/secure/ResetDevModeSession.dev?sessionToken=ab12", DevModeInstaller.RenewUrl("ab12").AbsoluteUri);
    }

    [Fact]
    public void VersionComparisonIsNumeric()
    {
        Assert.True(DevModeInstaller.IsNewer("0.10.0", "0.9.9"));
        Assert.False(DevModeInstaller.IsNewer("0.6.1", "0.6.1"));
        Assert.False(DevModeInstaller.IsNewer("0.6.0", "0.6.1"));
    }

    [Fact]
    public async Task MissingAppHasNoVersion()
    {
        var runner = new FakeRunner { Answer = _ => new CommandResult(1, "No such file") };
        Assert.Null(await Installer(runner).InstalledVersionAsync());
    }

    [Fact]
    public async Task RefusedKeyAndUnreachableTvAreDifferentProblems()
    {
        var refused = new FakeRunner { Answer = _ => new CommandResult(255, "prisoner@tv: Permission denied (publickey).") };
        var error = await Assert.ThrowsAsync<DevModeException>(() => Installer(refused).InstalledVersionAsync());
        Assert.Equal(DevModeError.KeyRefused, error.Error);

        var off = new FakeRunner { Answer = _ => new CommandResult(255, "connect to host port 9922: timed out") };
        error = await Assert.ThrowsAsync<DevModeException>(() => Installer(off).InstalledVersionAsync());
        Assert.Equal(DevModeError.Unreachable, error.Error);
    }

    [Fact]
    public async Task InstallUploadsThenAsksTheTvToInstallAndWaitsForTheVersion()
    {
        var reads = 0;
        var runner = new FakeRunner
        {
            Answer = line =>
            {
                if (!line.Contains("appinfo.json")) return null;
                reads++;
                return new CommandResult(0, reads < 3 ? "\"version\": \"0.4.0\"" : "\"version\": \"0.6.1\"");
            },
        };
        await Installer(runner).InstallAsync("tv.ipk", "0.6.1");
        Assert.Equal("tv.ipk", runner.Calls[0].Input);
        Assert.Contains("cat > /media/developer/temp/couchsubs.ipk", runner.Calls[0].Arguments[^1]);
        Assert.Contains("luna://com.webos.appInstallService/dev/install", runner.Calls[1].Arguments[^1]);
        Assert.Contains("rm -f /media/developer/temp/couchsubs.ipk", runner.Calls[^1].Arguments[^1]);
    }

    [Fact]
    public async Task InstallTimesOutWhenTheVersionNeverChanges()
    {
        var runner = new FakeRunner { Answer = line => line.Contains("appinfo.json") ? new CommandResult(0, "\"version\": \"0.4.0\"") : null };
        var error = await Assert.ThrowsAsync<DevModeException>(() => Installer(runner).InstallAsync("tv.ipk", "0.6.1"));
        Assert.Equal(DevModeError.InstallFailed, error.Error);
    }

    [Fact]
    public async Task FailedUploadStopsBeforeInstalling()
    {
        var runner = new FakeRunner { Answer = line => line.Contains("cat >") ? new CommandResult(1, "disk full") : null };
        await Assert.ThrowsAsync<DevModeException>(() => Installer(runner).InstallAsync("tv.ipk", "0.6.1"));
        Assert.DoesNotContain(runner.Calls, call => call.Arguments[^1].Contains("appInstallService"));
    }

    [Fact]
    public async Task SshUsesTheTvPortKeyAndOldKeyTypes()
    {
        var runner = new FakeRunner();
        await Installer(runner).InstalledVersionAsync();
        var arguments = runner.Calls[0].Arguments;
        Assert.Equal("ssh", runner.Calls[0].Executable);
        Assert.Contains("9922", arguments);
        Assert.Contains("BatchMode=yes", arguments);
        Assert.Contains("PubkeyAcceptedAlgorithms=+ssh-rsa", arguments);
        Assert.Contains("UserKnownHostsFile=NUL", arguments);
        Assert.Contains("prisoner@192.168.1.230", arguments);
    }

    [Fact]
    public async Task RealRunnerPassesEmptyArgumentsAndInput()
    {
        if (OperatingSystem.IsWindows()) return;
        var file = Path.GetTempFileName();
        await File.WriteAllTextAsync(file, "merhaba");
        try
        {
            var result = await new ProcessRunner().RunAsync("/bin/cat", [], file);
            Assert.Equal(new CommandResult(0, "merhaba"), result);
        }
        finally
        {
            File.Delete(file);
        }
    }
}
