// SPDX-License-Identifier: AGPL-3.0-only

import AppKit
import CouchSubsCore
import Darwin
import Observation
import RemotePlay

enum StoreKey {
    static let accountId = "accountId"
    static let console = "console"
    static let tv = "tv"
    static let tvKey = "tvKey"
    static let settings = "settings"
}

/// Kalıcı ayarlar (Anahtarlık değil, sıradan tercihler).
struct UserSettings: Codable, Equatable {
    var region = CropRegion()
    var style = SubtitleStyle()
    var sourceLanguage = "en"
    var targetLanguage = "tr"
}

protocol AppStore: AnyObject {
    func save<T: Encodable>(_ value: T, for key: String)
    func load<T: Decodable>(_ type: T.Type, for key: String) -> T?
    func remove(_ key: String)
}

final class KeychainStore: AppStore {
    func save<T: Encodable>(_ value: T, for key: String) { SecureStore.save(value, for: key) }
    func load<T: Decodable>(_ type: T.Type, for key: String) -> T? { SecureStore.load(type, for: key) }
    func remove(_ key: String) { SecureStore.remove(key) }
}

/// Dış dünyayla (PS5, PSN, TV) konuşan her şey; testlerde sahtesi kullanılır.
protocol AppServices: AnyObject {
    func discoverConsoles() async -> [ConsoleInfo]
    func accountId(fromRedirect url: URL) async throws -> Data
    func register(host: String, accountId: Data, pin: UInt32) async throws -> RegisteredConsole
    func discoverTVs() async -> [LGTV]
    /// TV ile eşleşir, TV uygulamasını sunucu adresiyle başlatır ve client-key'i döner.
    func pairTV(_ tv: LGTV, key: String?, server: String) async throws -> String
    func makeStream(console: RegisteredConsole, accountId: Data) -> StreamControlling
    func makeKeeper(tv: LGTV, key: String?, params: [String: Any]) -> KeeperControlling
}

/// PS5 bağlantısı (gerçekte `StreamSession`).
protocol StreamControlling: AnyObject {
    var onFrame: ((CGImage) -> Void)? { get set }
    var onState: ((SessionState) -> Void)? { get set }
    func start()
    func stop()
    func reconnectNow()
}

/// TV uygulamasını açık tutan görevli (gerçekte `TVKeeper`).
protocol KeeperControlling: AnyObject {
    func start(interval: Duration)
    func stop()
    func reconnect()
}

extension StreamSession: StreamControlling {}
extension TVKeeper: KeeperControlling {}

final class LiveServices: AppServices {
    func discoverConsoles() async -> [ConsoleInfo] { await Console.discover() }

    func accountId(fromRedirect url: URL) async throws -> Data {
        guard let code = PSNAccount.code(fromRedirect: url) else { throw AppError.invalidLogin }
        return try await PSNAccount.accountId(code: code)
    }

    func register(host: String, accountId: Data, pin: UInt32) async throws -> RegisteredConsole {
        try await Registration.register(host: host, accountId: accountId, pin: pin)
    }

    func discoverTVs() async -> [LGTV] { await LGDiscovery.search() }

    func pairTV(_ tv: LGTV, key: String?, server: String) async throws -> String {
        let client = SSAPClient(tv: tv, clientKey: key)
        let newKey = try await client.connect()
        try await client.launch(appId: AppIdentity.tvAppId, params: ["server": server])
        client.close()
        return newKey
    }

    func makeStream(console: RegisteredConsole, accountId: Data) -> StreamControlling {
        StreamSession(console: console, accountId: accountId)
    }

    func makeKeeper(tv: LGTV, key: String?, params: [String: Any]) -> KeeperControlling {
        TVKeeper(connect: {
            let client = SSAPClient(tv: tv, clientKey: key)
            _ = try await client.connect()
            return client
        }, appId: AppIdentity.tvAppId, params: params)
    }
}

enum AppError: LocalizedError, Equatable {
    case invalidPin, invalidLogin, missingAccount, wrongAccount, registrationFailed

    var errorDescription: String? {
        switch self {
        case .invalidPin: String(localized: "The code must be 8 digits.")
        case .invalidLogin: String(localized: "Sign-in did not complete. Please try again.")
        case .missingAccount: String(localized: "Sign in to PlayStation Network first.")
        case .wrongAccount: String(localized: "The PS5 did not recognise this account. Get the code from the PS5 user signed in with the account you used in CouchSubs, or sign in again with that user's account.")
        case .registrationFailed: String(localized: "The PS5 refused the code. Open Pair Device again on the PS5 and enter the new code.")
        }
    }
}

@MainActor
@Observable
final class AppModel {
    enum Step: Int, CaseIterable {
        case welcome, secondAccount, psnLogin, console, tv, test, done
    }

    var step: Step
    var accountId: Data?
    var console: RegisteredConsole?
    var tv: LGTV?
    var settings: UserSettings {
        didSet {
            // Sıradan tercih; her kaydırıcı hareketinde Anahtarlık'a yazılmasın.
            if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: StoreKey.settings) }
            server.sendStyle(settings.style)
            if isRunning, settings.sourceLanguage != oldValue.sourceLanguage || settings.targetLanguage != oldValue.targetLanguage {
                Task { await refreshTranslatorStatus() }
                makePipeline()
            }
        }
    }

    // Çalışma durumu
    var isRunning = false
    var isStarting = false
    var sessionState: SessionState = .disconnected(.stopped)
    /// Çeviri sürerken Mac'in boşta uykuya geçmesi engellenir (kullanıcı TV'de oynuyor, Mac'e dokunmuyor).
    var isPreventingSleep: Bool { sleepActivity != nil }
    var tvClients = 0
    var lastSource = ""
    var lastTranslation = ""
    var translatorStatus: TranslatorStatus = .ready
    var lastFrame: CGImage?
    var showAbout = false
    var showSettings = false

    private let services: AppServices
    private let store: AppStore
    private let defaults: UserDefaults
    /// Çalışan okuma hattının dilleri.
    private(set) var activeLanguages: (source: String, target: String)?
    private var server = SubtitleServer(port: AppIdentity.serverPort)
    private var serverStarted = false
    /// Sunucunun gerçekten dinlediği port (8787 doluysa rastgele bir port).
    private(set) var serverPort: UInt16 = AppIdentity.serverPort
    private var session: StreamControlling?
    private var keeper: KeeperControlling?
    private var sleepActivity: NSObjectProtocol?
    private var pipeline: SubtitlePipeline?
    private var processing = false
    private var wakeObserver: NSObjectProtocol?

    init(services: AppServices = LiveServices(), store: AppStore = KeychainStore(), defaults: UserDefaults = .standard) {
        self.services = services
        self.store = store
        self.defaults = defaults
        let accountId = store.load(Data.self, for: StoreKey.accountId)
        let console = store.load(RegisteredConsole.self, for: StoreKey.console)
        let tv = store.load(LGTV.self, for: StoreKey.tv)
        let ready = accountId != nil && console != nil && tv != nil && store.load(String.self, for: StoreKey.tvKey) != nil
        self.accountId = accountId
        self.console = console
        self.tv = tv
        settings = defaults.data(forKey: StoreKey.settings).flatMap { try? JSONDecoder().decode(UserSettings.self, from: $0) } ?? UserSettings()
        step = ready ? .done : .welcome
        server.onClientsChanged = { [weak self] count in self?.tvClients = count }
    }

    // MARK: - Sihirbaz

    var canAdvance: Bool {
        switch step {
        case .welcome, .secondAccount, .test: true
        case .psnLogin: accountId != nil
        case .console: console != nil
        case .tv: tv != nil && store.load(String.self, for: StoreKey.tvKey) != nil
        case .done: false
        }
    }

    func advance() {
        guard canAdvance, let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    func completePSNLogin(redirect: URL) async throws {
        let id = try await services.accountId(fromRedirect: redirect)
        accountId = id
        store.save(id, for: StoreKey.accountId)
    }

    func discoverConsoles() async -> [ConsoleInfo] { await services.discoverConsoles() }

    func register(host: String, pin: String) async throws {
        let digits = pin.filter(\.isNumber)
        guard digits.count == 8, let value = UInt32(digits) else { throw AppError.invalidPin }
        guard let accountId else { throw AppError.missingAccount }
        let registered: RegisteredConsole
        do {
            registered = try await services.register(host: host, accountId: accountId, pin: value)
        } catch Registration.RegistrationError.wrongAccount {
            throw AppError.wrongAccount
        } catch is Registration.RegistrationError {
            throw AppError.registrationFailed
        }
        console = registered
        store.save(registered, for: StoreKey.console)
    }

    func discoverTVs() async -> [LGTV] { await services.discoverTVs() }

    func pair(_ tv: LGTV) async throws {
        try await startServer()
        let key = try await services.pairTV(tv, key: store.load(String.self, for: StoreKey.tvKey), server: serverAddress(for: tv))
        self.tv = tv
        store.save(tv, for: StoreKey.tv)
        store.save(key, for: StoreKey.tvKey)
    }

    func sendTestSubtitle() {
        server.sendStyle(settings.style)
        server.sendSubtitle(String(localized: "This is a test subtitle. Can you see it on top of the game?"), durationMs: 8000)
    }

    /// Kurulumu baştan başlatır (kayıtlı her şeyi siler).
    func resetSetup() {
        stop()
        [StoreKey.accountId, StoreKey.console, StoreKey.tv, StoreKey.tvKey].forEach(store.remove)
        accountId = nil
        console = nil
        tv = nil
        step = .welcome
    }

    // MARK: - Çeviri

    func start() async {
        // Düğmeye iki kez basılması ya da beklerken tekrar çağrılması ikinci bir oturum açmaz.
        guard !isRunning, !isStarting, let console, let accountId, let tv else { return }
        isStarting = true
        defer { isStarting = false }

        translatorStatus = await Translator.status(source: settings.sourceLanguage, target: settings.targetLanguage)
        try? await startServer()
        server.sendStyle(settings.style)

        makePipeline()

        let session = services.makeStream(console: console, accountId: accountId)
        session.onState = { [weak self] state in Task { @MainActor in self?.sessionStateChanged(state) } }
        session.onFrame = { [weak self] frame in Task { @MainActor in await self?.handle(frame) } }
        session.start()
        self.session = session

        // TV uygulamasını başlat ve açık tut; TV kapalıysa açıldığında bağlanır.
        let keeper = services.makeKeeper(tv: tv, key: store.load(String.self, for: StoreKey.tvKey), params: ["server": serverAddress(for: tv)])
        keeper.start(interval: .seconds(5))
        self.keeper = keeper

        // Mac uykudan uyanınca bağlantıları hemen yenile.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.session?.reconnectNow()
                self?.keeper?.reconnect()
            }
        }
        sleepActivity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled],
                                                              reason: "Translating game subtitles")
        isRunning = true
    }

    /// Okuma hattını güncel dillerle (yeniden) kurar.
    private func makePipeline() {
        pipeline?.reset()
        let pipeline = SubtitlePipeline(reader: VisionReader(language: settings.sourceLanguage),
                                        translator: Translator(source: settings.sourceLanguage, target: settings.targetLanguage),
                                        server: server)
        pipeline.onPair = { [weak self] source, translation in
            self?.lastSource = source
            self?.lastTranslation = translation
        }
        // Dil paketi bu arada indirilmiş olabilir; her çeviri sonucu durumu günceller.
        pipeline.onTranslationResult = { [weak self] error in
            self?.translatorStatus = Self.translatorStatus(after: error)
        }
        pipeline.warmUp()
        self.pipeline = pipeline
        activeLanguages = (settings.sourceLanguage, settings.targetLanguage)
    }

    private func refreshTranslatorStatus() async {
        translatorStatus = await Translator.status(source: settings.sourceLanguage, target: settings.targetLanguage)
    }

    func stop() {
        session?.stop()
        session = nil
        keeper?.stop()
        keeper = nil
        pipeline?.reset()
        pipeline = nil
        activeLanguages = nil
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        if let sleepActivity { ProcessInfo.processInfo.endActivity(sleepActivity) }
        sleepActivity = nil
        isRunning = false
        sessionState = .disconnected(.stopped)
    }

    private func sessionStateChanged(_ state: SessionState) {
        sessionState = state
        // Bağlantı koptuysa TV'de eski altyazı kalmasın.
        if case .disconnected = state {
            pipeline?.reset()
            server.clear()
        }
    }

    static func translatorStatus(after error: TranslatorError?) -> TranslatorStatus {
        switch error {
        case nil: .ready
        case .needsDownload: .needsDownload
        case .unsupported: .unsupported
        }
    }

    /// Çeviri başlamamışken bağlı olmamak bir sorun değildir; nokta gri kalır.
    static func ps5Tone(_ state: SessionState, running: Bool) -> StatusTone {
        state == .streaming ? .good : running ? .warning : .idle
    }

    static func tvTone(clients: Int, running: Bool) -> StatusTone {
        clients > 0 ? .good : running ? .warning : .idle
    }

    /// PS5 durumunun kullanıcıya gösterilecek metni.
    static func statusText(_ state: SessionState, running: Bool) -> String {
        switch state {
        case .streaming: return String(localized: "Connected")
        case .connecting: return String(localized: "Connecting…")
        case .disconnected(let reason):
            guard running else { return String(localized: "Not connected") }
            switch reason {
            case .consoleAsleep: return String(localized: "Turn on your PS5")
            case .inUse: return String(localized: "Remote Play is in use on another device")
            case .refused: return String(localized: "The PS5 refused the connection. Set up the PS5 again.")
            case .loginPasscode: return String(localized: "The second user has a login passcode on the PS5. Turn it off in Settings › Users and Accounts.")
            default: return String(localized: "Reconnecting…")
            }
        }
    }

    private func handle(_ frame: CGImage) async {
        lastFrame = frame
        // Önceki kare hâlâ işleniyorsa bu kare atlanır; okuma kareleri biriktirmez.
        guard !processing, let pipeline else { return }
        processing = true
        await pipeline.process(frame, region: settings.region)
        processing = false
    }

    private func startServer() async throws {
        guard !serverStarted else { return }
        do {
            serverPort = try await server.start()
        } catch {
            // 8787 başka bir uygulamada; TV'ye zaten adres bildirildiği için herhangi bir boş port olur.
            server = SubtitleServer(port: 0)
            server.onClientsChanged = { [weak self] count in self?.tvClients = count }
            serverPort = try await server.start()
        }
        serverStarted = true
    }

    /// TV ile aynı ağdaki Mac adresi.
    private func serverAddress(for tv: LGTV) -> String {
        "http://\(Self.localAddress(near: tv.host) ?? "127.0.0.1"):\(serverPort)"
    }

    static func localAddress(near host: String) -> String? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        let target = inet_addr(host)
        var fallback: String?
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            guard Int32(entry.ifa_flags) & IFF_LOOPBACK == 0, entry.ifa_addr?.pointee.sa_family == sa_family_t(AF_INET),
                  let mask = entry.ifa_netmask else { continue }
            let address = entry.ifa_addr!.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            let netmask = mask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
            let text = String(cString: inet_ntoa(address))
            if address.s_addr & netmask == target & netmask { return text }
            fallback = fallback ?? text
        }
        return fallback
    }
}
