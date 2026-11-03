// SPDX-License-Identifier: AGPL-3.0-only

using System.ComponentModel;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Runtime.CompilerServices;
using CouchSubs.Core;
using CouchSubs.Core.LgTv;
using CouchSubs.RemotePlay;

namespace CouchSubs.Shell;

/// <summary>
/// Uygulamanın durumu ve akışı (Mac'teki AppModel'in karşılığı): kurulum sihirbazı, çeviriyi
/// başlatma/durdurma, PS5 ve TV durumları. Arayüz bu nesneye bağlanır; olaylar <c>post</c> ile
/// arayüz iş parçacığına aktarılır.
/// </summary>
public sealed class AppController : INotifyPropertyChanged, IDisposable
{
    public const string TvAppId = "com.couchsubs.tv";
    public const int DefaultServerPort = 8787;

    private readonly IAppServices services;
    private readonly IAppStore store;
    private readonly ISettingsStore settingsStore;
    private readonly ISleepGuard sleep;
    private readonly Localizer text;
    private readonly Action<Action> post;

    private OnboardingStep step;
    private byte[]? accountId;
    private RegisteredConsole? console;
    private LgTv? tv;
    private TvAppState tvApp = TvAppState.Unknown;
    /// <summary>Son eşleşmede TV uygulaması açılamadı.</summary>
    private bool tvAppMissing;
    private UserSettings settings;
    private bool isRunning;
    private bool isStarting;
    private SessionState sessionState = SessionState.Disconnected(DisconnectKind.Stopped);
    private int tvClients;
    private string lastSource = "";
    private string lastTranslation = "";
    private TranslatorStatus translatorStatus = TranslatorStatus.Ready;
    private bool ocrMissing;
    private Frame? lastFrame;
    private bool modelDownloading;
    private double modelProgress;
    private string? modelError;
    private Task? modelDownload;

    private SubtitleServer server = new(DefaultServerPort);
    private bool serverStarted;
    private IStreamSession? session;
    private IKeeper? keeper;
    private SubtitlePipeline? pipeline;
    private int processing;

    public event PropertyChangedEventHandler? PropertyChanged;

    public AppController(IAppServices services, IAppStore store, ISettingsStore settingsStore, ISleepGuard sleep, Localizer text, Action<Action> post)
    {
        this.services = services;
        this.store = store;
        this.settingsStore = settingsStore;
        this.sleep = sleep;
        this.text = text;
        this.post = post;
        accountId = store.Load<byte[]>(StoreKeys.AccountId);
        console = store.Load<RegisteredConsole>(StoreKeys.Console);
        tv = store.Load<LgTv>(StoreKeys.Tv);
        settings = settingsStore.Load();
        var ready = accountId is not null && console is not null && tv is not null && store.Load<string>(StoreKeys.TvKey) is not null;
        step = ready ? OnboardingStep.Done : OnboardingStep.Welcome;
        server.ClientsChanged += OnClientsChanged;
    }

    // --- Durum ---

    public OnboardingStep Step { get => step; set => Set(ref step, value, [nameof(CanAdvance), nameof(StepNumber)]); }
    public static int StepCount => (int)OnboardingStep.Done;
    public int StepNumber => Math.Min((int)step + 1, StepCount);
    public bool HasAccount => accountId is not null;
    public RegisteredConsole? Console => console;
    public LgTv? Tv => tv;
    public bool IsRunning { get => isRunning; private set => Set(ref isRunning, value, [nameof(Ps5StatusText), nameof(Ps5Tone), nameof(TvTone)]); }
    public bool IsStarting { get => isStarting; private set => Set(ref isStarting, value); }
    public SessionState SessionState { get => sessionState; private set => Set(ref sessionState, value, [nameof(Ps5StatusText), nameof(Ps5Tone)]); }
    public string Ps5StatusText => StatusText(sessionState, isRunning, text);
    public StatusTone Ps5Tone => Ps5ToneFor(sessionState, isRunning);
    public int TvClients { get => tvClients; private set => Set(ref tvClients, value, [nameof(TvTone), nameof(TvStatusText)]); }
    public StatusTone TvTone => TvToneFor(tvClients, isRunning);
    public string TvStatusText => tvClients > 0 ? text["Connected"] : text["Waiting for the TV app"];
    public string LastSource { get => lastSource; private set => Set(ref lastSource, value); }
    public string LastTranslation { get => lastTranslation; private set => Set(ref lastTranslation, value); }
    public TranslatorStatus TranslatorStatus { get => translatorStatus; private set => Set(ref translatorStatus, value); }
    /// <summary>Bilgisayarda yazı tanıma dili yok; ayarlardan eklenmesi gerekir.</summary>
    public bool OcrMissing { get => ocrMissing; private set => Set(ref ocrMissing, value); }
    public Frame? LastFrame { get => lastFrame; private set => Set(ref lastFrame, value); }
    public string? ActiveSourceLanguage { get; private set; }
    /// <summary>Sunucunun gerçekten dinlediği port (8787 doluysa rastgele bir port).</summary>
    public int ServerPort { get; private set; } = DefaultServerPort;

    /// <summary>Bu oyun dilinden hedef dile çeviri modeli var mı (ayarlarda listelenecek diller).</summary>
    public bool SupportsLanguage(string source) => services.Translation.IsSupported(source, settings.TargetLanguage);

    public bool ModelInstalled => services.Translation.IsInstalled(settings.SourceLanguage, settings.TargetLanguage);
    public bool ModelDownloading { get => modelDownloading; private set => Set(ref modelDownloading, value); }
    public double ModelProgress { get => modelProgress; private set => Set(ref modelProgress, value); }
    public string? ModelError { get => modelError; private set => Set(ref modelError, value); }

    public UserSettings Settings
    {
        get => settings;
        set
        {
            var old = settings;
            if (!Set(ref settings, value)) return;
            settingsStore.Save(value);
            server.SendStyle(value.Style);
            if (isRunning && (old.SourceLanguage != value.SourceLanguage || old.TargetLanguage != value.TargetLanguage))
            {
                RefreshTranslatorStatus();
                MakePipeline();
            }
        }
    }

    // --- Sihirbaz ---

    public bool CanAdvance => step switch
    {
        OnboardingStep.Welcome or OnboardingStep.SecondAccount or OnboardingStep.Test => true,
        OnboardingStep.PsnLogin => accountId is not null,
        OnboardingStep.Console => console is not null,
        OnboardingStep.Tv => tv is not null && store.Load<string>(StoreKeys.TvKey) is not null,
        OnboardingStep.Translation => ModelInstalled,
        _ => false,
    };

    public void Advance()
    {
        if (!CanAdvance || step == OnboardingStep.Done) return;
        // Model büyük; kullanıcı diğer adımlarla uğraşırken arka planda iner.
        if (step == OnboardingStep.Welcome) StartModelDownload();
        Step = step + 1;
    }

    public void Back()
    {
        if (step > OnboardingStep.Welcome) Step = step - 1;
    }

    public async Task CompletePsnLoginAsync(Uri redirect)
    {
        var id = await services.AccountIdFromRedirectAsync(redirect);
        accountId = id;
        store.Save(StoreKeys.AccountId, id);
        Changed(nameof(HasAccount), nameof(CanAdvance));
    }

    public Task<IReadOnlyList<ConsoleInfo>> DiscoverConsolesAsync() => services.DiscoverConsolesAsync();

    public async Task RegisterAsync(string host, string pin)
    {
        var digits = new string([.. pin.Where(char.IsDigit)]);
        if (digits.Length != 8 || !uint.TryParse(digits, out var value)) throw Error(AppError.InvalidPin);
        if (accountId is null) throw Error(AppError.MissingAccount);
        RegisteredConsole registered;
        try
        {
            registered = await services.RegisterAsync(host, accountId, value);
        }
        catch (RegistrationException error)
        {
            throw Error(error.Failure == RegistrationFailure.WrongAccount ? AppError.WrongAccount : AppError.RegistrationFailed);
        }
        console = registered;
        store.Save(StoreKeys.Console, registered);
        Changed(nameof(Console), nameof(CanAdvance));
    }

    public Task<IReadOnlyList<LgTv>> DiscoverTvsAsync() => services.DiscoverTvsAsync();

    public async Task PairAsync(LgTv target)
    {
        await StartServerAsync();
        var pairing = await services.PairTvAsync(target, store.Load<string>(StoreKeys.TvKey), ServerAddress(target));
        tv = target;
        store.Save(StoreKeys.Tv, target);
        store.Save(StoreKeys.TvKey, pairing.Key);
        tvAppMissing = !pairing.Launched;
        Changed(nameof(Tv), nameof(CanAdvance));
        await RefreshTvAppAsync();
    }

    // --- TV uygulamasını kurma ---

    public TvAppState TvApp
    {
        get => tvApp;
        private set
        {
            tvApp = value;
            Changed(nameof(TvApp));
        }
    }

    /// <summary>
    /// Geliştirici modu açık TV'de uygulamayı eksikse kurar, eskiyse günceller.
    /// Anahtar yoksa ve uygulama çalışıyorsa kullanıcıdan bir şey istenmez.
    /// </summary>
    public async Task RefreshTvAppAsync()
    {
        if (tv is not { Brand: TvBrand.Lg } target || services.BundledTvAppVersion is not { } bundled) return;
        if (!await services.IsDevModeOnAsync(target.Host))
        {
            TvApp = tvAppMissing ? new TvAppState(TvAppKind.DevModeOff) : TvAppState.Unknown;
            return;
        }
        if (store.Load<string>(StoreKeys.TvDevKey) is not { } devKey)
        {
            TvApp = tvAppMissing ? new TvAppState(TvAppKind.NeedsPassphrase) : TvAppState.Unknown;
            return;
        }
        await InstallTvAppAsync(target, devKey, bundled);
    }

    /// <summary>Key Server'dan anahtarı alır (TV ekranındaki parolayla) ve uygulamayı kurar.</summary>
    public async Task InstallTvAppAsync(string passphrase)
    {
        if (tv is not { } target || services.BundledTvAppVersion is not { } bundled) return;
        TvApp = new TvAppState(TvAppKind.Working);
        try
        {
            var devKey = await services.FetchDevKeyAsync(target.Host, passphrase.Trim());
            store.Save(StoreKeys.TvDevKey, devKey);
            await InstallTvAppAsync(target, devKey, bundled);
        }
        catch (DevModeException error)
        {
            TvApp = new TvAppState(TvAppKind.NeedsPassphrase, Error: error.Error);
        }
    }

    private async Task InstallTvAppAsync(LgTv target, string devKey, string bundled)
    {
        TvApp = new TvAppState(TvAppKind.Working);
        try
        {
            var installed = await services.InstalledTvAppVersionAsync(target.Host, devKey);
            if (installed is not null && !DevModeInstaller.IsNewer(bundled, installed))
            {
                TvApp = new TvAppState(TvAppKind.UpToDate, installed);
                return;
            }
            await services.InstallTvAppAsync(target.Host, devKey);
            TvApp = new TvAppState(TvAppKind.UpToDate, bundled);
            tvAppMissing = false;
            await OpenTvAppAfterInstallAsync(target);
        }
        catch (DevModeException error) when (error.Error == DevModeError.KeyRefused)
        {
            // Geliştirici modu yeniden açılınca TV yeni anahtar üretir; eskisi işe yaramaz.
            store.Remove(StoreKeys.TvDevKey);
            TvApp = new TvAppState(TvAppKind.NeedsPassphrase);
        }
        catch (DevModeException error)
        {
            TvApp = new TvAppState(TvAppKind.Failed, Error: error.Error);
        }
    }

    private async Task OpenTvAppAfterInstallAsync(LgTv target)
    {
        if (keeper is not null)
        {
            keeper.Reconnect();
            return;
        }
        try { await services.PairTvAsync(target, store.Load<string>(StoreKeys.TvKey), ServerAddress(target)); }
        catch (Exception) { /* TV uygulaması kuruldu; açılmadıysa kullanıcı açabilir */ }
    }

    /// <summary>TV ağda yeni bir adreste bulundu.</summary>
    public void TvMoved(LgTv moved)
    {
        tv = moved;
        store.Save(StoreKeys.Tv, moved);
        Changed(nameof(Tv));
    }

    public void StartModelDownload()
    {
        if (ModelInstalled || modelDownload is { IsCompleted: false }) return;
        ModelDownloading = true;
        ModelError = null;
        var download = services.Translation.DownloadAsync(settings.SourceLanguage, settings.TargetLanguage, new ImmediateProgress(value => post(() => ModelProgress = value)), CancellationToken.None);
        modelDownload = FinishDownload(download);
    }

    private async Task FinishDownload(Task download)
    {
        try
        {
            await download;
            post(() => ModelProgress = 1);
        }
        catch (Exception error)
        {
            post(() => ModelError = error.Message);
        }
        finally
        {
            post(() =>
            {
                ModelDownloading = false;
                Changed(nameof(ModelInstalled), nameof(CanAdvance));
                RefreshTranslatorStatus();
                // Çeviri sürerken model indiyse hat yeni çevirmenle kurulur.
                if (isRunning && TranslatorStatus == TranslatorStatus.Ready) MakePipeline();
            });
        }
    }

    public Task WaitForModelAsync() => modelDownload ?? Task.CompletedTask;

    public void SendTestSubtitle()
    {
        server.SendStyle(settings.Style);
        server.SendSubtitle(text["This is a test subtitle. Can you see it on top of the game?"], 8000);
    }

    /// <summary>Kurulumu baştan başlatır (kayıtlı her şeyi siler).</summary>
    public void ResetSetup()
    {
        Stop();
        foreach (var key in new[] { StoreKeys.AccountId, StoreKeys.Console, StoreKeys.Tv, StoreKeys.TvKey, StoreKeys.TvDevKey }) store.Remove(key);
        accountId = null;
        console = null;
        tv = null;
        tvAppMissing = false;
        TvApp = TvAppState.Unknown;
        Step = OnboardingStep.Welcome;
        Changed(nameof(HasAccount), nameof(Console), nameof(Tv));
    }

    // --- Çeviri ---

    public async Task StartAsync()
    {
        // Düğmeye iki kez basılması ya da beklerken tekrar çağrılması ikinci bir oturum açmaz.
        if (isRunning || isStarting || console is null || accountId is null || tv is null) return;
        IsStarting = true;
        try
        {
            RefreshTranslatorStatus();
            try { await StartServerAsync(); } catch { /* port açılamadıysa TV durumu "bekleniyor" kalır */ }
            server.SendStyle(settings.Style);
            MakePipeline();

            var stream = services.MakeStream(console, accountId);
            stream.StateChanged += state => post(() => SessionStateChanged(state));
            stream.FrameReceived += HandleFrame;
            stream.Start();
            session = stream;

            // TV uygulamasını başlat ve açık tut; TV kapalıysa açıldığında bağlanır.
            var tvKeeper = services.MakeKeeper(tv, store.Load<string>(StoreKeys.TvKey), new Dictionary<string, string> { ["server"] = ServerAddress(tv) },
                moved => post(() => TvMoved(moved)));
            tvKeeper.Start(TimeSpan.FromSeconds(5));
            keeper = tvKeeper;
            _ = RefreshTvAppAsync();

            sleep.Begin();
            IsRunning = true;
        }
        finally
        {
            IsStarting = false;
        }
    }

    public void Stop()
    {
        session?.Stop();
        session?.Dispose();
        session = null;
        keeper?.Stop();
        keeper = null;
        pipeline?.Reset();
        pipeline = null;
        ActiveSourceLanguage = null;
        if (isRunning) sleep.End();
        IsRunning = false;
        SessionState = SessionState.Disconnected(DisconnectKind.Stopped);
    }

    /// <summary>Bilgisayar uykudan uyanınca bağlantıları hemen yenile.</summary>
    public void SystemResumed()
    {
        session?.ReconnectNow();
        keeper?.Reconnect();
    }

    /// <summary>Çeviri başlamamışken bağlı olmamak bir sorun değildir; nokta gri kalır.</summary>
    public static StatusTone Ps5ToneFor(SessionState state, bool running) =>
        state.Phase == SessionPhase.Streaming ? StatusTone.Good : running ? StatusTone.Warning : StatusTone.Idle;

    public static StatusTone TvToneFor(int clients, bool running) =>
        clients > 0 ? StatusTone.Good : running ? StatusTone.Warning : StatusTone.Idle;

    /// <summary>PS5 durumunun kullanıcıya gösterilecek metni.</summary>
    public static string StatusText(SessionState state, bool running, Localizer text)
    {
        switch (state.Phase)
        {
            case SessionPhase.Streaming: return text["Connected"];
            case SessionPhase.Connecting: return text["Connecting…"];
        }
        if (!running) return text["Not connected"];
        return text[state.Reason?.Kind switch
        {
            DisconnectKind.ConsoleAsleep => "Turn on your PS5",
            DisconnectKind.InUse => "Remote Play is in use on another device",
            DisconnectKind.Refused => "The PS5 refused the connection. Set up the PS5 again.",
            DisconnectKind.LoginPasscode => "The second user has a login passcode on the PS5. Turn it off in Settings › Users and Accounts.",
            _ => "Reconnecting…",
        }];
    }

    public void Dispose()
    {
        Stop();
        server.Dispose();
    }

    // --- İç işleyiş ---

    /// <summary>Okuma hattını güncel dillerle (yeniden) kurar.</summary>
    private void MakePipeline()
    {
        pipeline?.Reset();
        pipeline = null;
        ActiveSourceLanguage = settings.SourceLanguage;
        var reader = services.MakeReader(settings.SourceLanguage);
        OcrMissing = reader is null;
        if (reader is null) return;
        var built = new SubtitlePipeline(reader, MakeTranslator(), server, new ReadScheduler());
        built.PairShown += (source, translation) => post(() =>
        {
            LastSource = source;
            LastTranslation = translation;
        });
        // Model bu arada inmiş olabilir; her çeviri sonucu durumu günceller.
        built.TranslationResult += error => post(() => TranslatorStatus = error ?? TranslatorStatus.Ready);
        pipeline = built;
    }

    private ITextTranslator MakeTranslator()
    {
        var translation = services.Translation;
        var (source, target) = (settings.SourceLanguage, settings.TargetLanguage);
        if (!translation.IsSupported(source, target)) return new UnavailableTranslator(TranslatorStatus.Unsupported);
        return translation.IsInstalled(source, target) ? translation.Create(source, target) : new UnavailableTranslator(TranslatorStatus.NeedsDownload);
    }

    private void RefreshTranslatorStatus()
    {
        var translation = services.Translation;
        TranslatorStatus = !translation.IsSupported(settings.SourceLanguage, settings.TargetLanguage) ? TranslatorStatus.Unsupported
            : translation.IsInstalled(settings.SourceLanguage, settings.TargetLanguage) ? TranslatorStatus.Ready
            : TranslatorStatus.NeedsDownload;
    }

    private void SessionStateChanged(SessionState state)
    {
        SessionState = state;
        // Bağlantı koptuysa TV'de eski altyazı kalmasın.
        if (state.Phase == SessionPhase.Disconnected)
        {
            pipeline?.Reset();
            server.Clear();
        }
    }

    private async void HandleFrame(Frame frame)
    {
        post(() => LastFrame = frame);
        // Önceki kare hâlâ işleniyorsa bu kare atlanır; okuma kareleri biriktirmez.
        var current = pipeline;
        if (current is null || Interlocked.Exchange(ref processing, 1) == 1) return;
        try
        {
            await current.ProcessAsync(frame, settings.Region);
        }
        catch
        {
            // Tek bir karenin okunamaması akışı durdurmaz.
        }
        finally
        {
            Volatile.Write(ref processing, 0);
        }
    }

    private async Task StartServerAsync()
    {
        if (serverStarted) return;
        try
        {
            ServerPort = await server.StartAsync();
        }
        catch (SocketException)
        {
            // 8787 başka bir uygulamada; TV'ye adres her seferinde bildirildiği için herhangi bir boş port olur.
            server.ClientsChanged -= OnClientsChanged;
            server = new SubtitleServer(0);
            server.ClientsChanged += OnClientsChanged;
            ServerPort = await server.StartAsync();
        }
        serverStarted = true;
    }

    private void OnClientsChanged(int count) => post(() => TvClients = count);

    /// <summary>TV ile aynı ağdaki bilgisayar adresi.</summary>
    private string ServerAddress(LgTv target) => $"http://{LocalAddress(target.Host) ?? "127.0.0.1"}:{ServerPort}";

    public static string? LocalAddress(string near)
    {
        if (!IPAddress.TryParse(near, out var target) || target.AddressFamily != AddressFamily.InterNetwork) return null;
        string? fallback = null;
        foreach (var network in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (network.OperationalStatus != OperationalStatus.Up || network.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;
            foreach (var unicast in network.GetIPProperties().UnicastAddresses)
            {
                if (unicast.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                var mask = unicast.IPv4Mask.GetAddressBytes();
                var address = unicast.Address.GetAddressBytes();
                var wanted = target.GetAddressBytes();
                if (Enumerable.Range(0, 4).All(i => (address[i] & mask[i]) == (wanted[i] & mask[i]))) return unicast.Address.ToString();
                fallback ??= unicast.Address.ToString();
            }
        }
        return fallback;
    }

    private AppException Error(AppError error) => new(error, AppException.Describe(error, text));

    /// <summary>Değer değiştiyse yazar ve özelliği (ve ona bağlı olanları) bildirir.</summary>
    private bool Set<T>(ref T field, T value, string[]? also = null, [CallerMemberName] string name = "")
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return false;
        field = value;
        Changed([name, .. also ?? []]);
        return true;
    }

    private void Changed(params string[] names)
    {
        foreach (var name in names) PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }

    /// <summary>Model eksikken ya da dil desteklenmezken kullanılan çevirmen: nedeni bildirir.</summary>
    private sealed class UnavailableTranslator(TranslatorStatus status) : ITextTranslator
    {
        public Task<string> TranslateAsync(string text, CancellationToken cancellationToken = default) => throw new TranslatorException(status);
    }

    /// <summary>İlerlemeyi bağlama yakalamadan doğrudan iletir (post zaten arayüze aktarır).</summary>
    private sealed class ImmediateProgress(Action<double> report) : IProgress<double>
    {
        public void Report(double value) => report(value);
    }
}
