// SPDX-License-Identifier: AGPL-3.0-only

using System.IO;
using System.Text.Json;
using CouchSubs.Core;
using CouchSubs.Core.LgTv;
using CouchSubs.RemotePlay;
using CouchSubs.Shell;
using CouchSubs.Translation;

namespace CouchSubs.App.Services;

/// <summary>Uygulama denetleyicisinin gerçek dünya bağlantıları (PS5, PSN, TV, OCR, çeviri).</summary>
public sealed class LiveServices : IAppServices
{
    public ITranslationModel Translation { get; } = new MarianModel();

    public Task<IReadOnlyList<ConsoleInfo>> DiscoverConsolesAsync() => ConsoleDiscovery.DiscoverAsync();

    public async Task<byte[]> AccountIdFromRedirectAsync(Uri redirect)
    {
        var code = PsnAccount.CodeFromRedirect(redirect)
                   ?? throw new AppException(AppError.InvalidLogin, AppException.Describe(AppError.InvalidLogin, Localizer.Current));
        return await PsnAccount.AccountIdAsync(code);
    }

    public Task<RegisteredConsole> RegisterAsync(string host, byte[] accountId, uint pin) => Registration.RegisterAsync(host, accountId, pin);

    public Task<IReadOnlyList<LgTv>> DiscoverTvsAsync() => LgDiscovery.SearchAsync();

    public async Task<string> PairTvAsync(LgTv tv, string? key, string server)
    {
        using var client = new SsapClient(tv, key);
        var newKey = await client.ConnectAsync();
        await client.LaunchAsync(AppController.TvAppId, new Dictionary<string, string> { ["server"] = server });
        return newKey;
    }

    public IStreamSession MakeStream(RegisteredConsole console, byte[] accountId) => new StreamSession(console, accountId);

    public IKeeper MakeKeeper(LgTv tv, string? key, IReadOnlyDictionary<string, string> parameters) =>
        new Keeper(new TvKeeper(async () =>
        {
            var client = new SsapClient(tv, key);
            await client.ConnectAsync();
            return client;
        }, AppController.TvAppId, parameters));

    public ITextReader? MakeReader(string language) => WindowsOcrReader.Create(language);

    private sealed class Keeper(TvKeeper keeper) : IKeeper
    {
        public void Start(TimeSpan interval) => keeper.Start(interval);
        public void Stop() => keeper.Stop();
        public void Reconnect() => keeper.Reconnect();
    }

    /// <summary>OPUS-MT modelleri; şimdilik yalnız İngilizce→Türkçe.</summary>
    private sealed class MarianModel : ITranslationModel
    {
        private readonly ModelStore englishTurkish = new(Path.Combine(AppPaths.Models, "en-tr"));
        private MarianTranslator? translator;

        public bool IsSupported(string source, string target) => source == "en" && target == "tr";

        public bool IsInstalled(string source, string target) => IsSupported(source, target) && englishTurkish.IsInstalled;

        public Task DownloadAsync(string source, string target, IProgress<double> progress, CancellationToken cancellationToken) =>
            englishTurkish.DownloadAsync(progress, cancellationToken);

        // Model belleğe bir kez yüklenir; dil değişse de aynı çevirmen kullanılır.
        public ITextTranslator Create(string source, string target) => translator ??= new MarianTranslator(englishTurkish.InstallDirectory);
    }
}

/// <summary>Şifreli depo (hesap, PS5, TV anahtarları).</summary>
public sealed class DpapiAppStore : IAppStore
{
    public void Save<T>(string key, T value) => SecureStore.Default.Save(key, value);
    public T? Load<T>(string key) => SecureStore.Default.Load<T>(key);
    public void Remove(string key) => SecureStore.Default.Remove(key);
}

/// <summary>Sıradan ayarlar: %LOCALAPPDATA%\CouchSubs\settings.json.</summary>
public sealed class FileSettingsStore : ISettingsStore
{
    private static readonly string FilePath = Path.Combine(AppPaths.Data, "settings.json");

    public UserSettings Load()
    {
        try { return JsonSerializer.Deserialize<UserSettings>(File.ReadAllText(FilePath)) ?? new UserSettings(); }
        catch (Exception error) when (error is IOException or JsonException or UnauthorizedAccessException) { return new UserSettings(); }
    }

    public void Save(UserSettings settings)
    {
        Directory.CreateDirectory(AppPaths.Data);
        File.WriteAllText(FilePath, JsonSerializer.Serialize(settings));
    }
}

public sealed class WindowsSleepGuard : ISleepGuard
{
    public void Begin() => SleepGuard.Begin();
    public void End() => SleepGuard.End();
}
