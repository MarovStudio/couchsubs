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
}

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
}

enum AppError: LocalizedError, Equatable {
    case invalidPin, invalidLogin, missingAccount

    var errorDescription: String? {
        switch self {
        case .invalidPin: String(localized: "The code must be 8 digits.")
        case .invalidLogin: String(localized: "Sign-in did not complete. Please try again.")
        case .missingAccount: String(localized: "Sign in to PlayStation Network first.")
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
        didSet { store.save(settings, for: StoreKey.settings); server.sendStyle(settings.style) }
    }

    // Çalışma durumu
    var isRunning = false
    var sessionState: SessionState = .disconnected(reason: "")
    var tvClients = 0
    var lastSource = ""
    var lastTranslation = ""
    var translatorStatus: TranslatorStatus = .ready
    var lastFrame: CGImage?
    var showAbout = false

    private let services: AppServices
    private let store: AppStore
    private var server = SubtitleServer(port: AppIdentity.serverPort)
    private var serverStarted = false
    /// Sunucunun gerçekten dinlediği port (8787 doluysa rastgele bir port).
    private(set) var serverPort: UInt16 = AppIdentity.serverPort
    private var session: StreamSession?
    private var keeper: TVKeeper?
    private var keeperClient: SSAPClient?
    private var pipeline: SubtitlePipeline?
    private var processing = false
    private var wakeObserver: NSObjectProtocol?

    init(services: AppServices = LiveServices(), store: AppStore = KeychainStore()) {
        self.services = services
        self.store = store
        let accountId = store.load(Data.self, for: StoreKey.accountId)
        let console = store.load(RegisteredConsole.self, for: StoreKey.console)
        let tv = store.load(LGTV.self, for: StoreKey.tv)
        let ready = accountId != nil && console != nil && tv != nil && store.load(String.self, for: StoreKey.tvKey) != nil
        self.accountId = accountId
        self.console = console
        self.tv = tv
        settings = store.load(UserSettings.self, for: StoreKey.settings) ?? UserSettings()
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
        let registered = try await services.register(host: host, accountId: accountId, pin: value)
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
        guard !isRunning, let console, let accountId, let tv else { return }
        translatorStatus = await Translator.status(source: settings.sourceLanguage, target: settings.targetLanguage)
        try? await startServer()
        server.sendStyle(settings.style)

        let pipeline = SubtitlePipeline(reader: VisionReader(language: settings.sourceLanguage),
                                        translator: Translator(source: settings.sourceLanguage, target: settings.targetLanguage),
                                        server: server)
        pipeline.onPair = { [weak self] source, translation in
            self?.lastSource = source
            self?.lastTranslation = translation
        }
        self.pipeline = pipeline

        let session = StreamSession(console: console, accountId: accountId)
        session.onState = { [weak self] state in Task { @MainActor in self?.sessionState = state } }
        session.onFrame = { [weak self] frame in Task { @MainActor in await self?.handle(frame) } }
        session.start()
        self.session = session

        // TV uygulamasını başlat ve TV başka girişe geçerse geri getir.
        let client = SSAPClient(tv: tv, clientKey: store.load(String.self, for: StoreKey.tvKey))
        let params = ["server": serverAddress(for: tv)]
        if (try? await client.connect()) != nil {
            try? await client.launch(appId: AppIdentity.tvAppId, params: params)
            let keeper = TVKeeper(control: client, appId: AppIdentity.tvAppId, params: params)
            keeper.start()
            self.keeper = keeper
            keeperClient = client
        }

        // Mac uykudan uyanınca bağlantıyı hemen yenile.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.session?.reconnectNow() }
        }
        isRunning = true
    }

    func stop() {
        session?.stop()
        session = nil
        keeper?.stop()
        keeper = nil
        keeperClient?.close()
        keeperClient = nil
        pipeline?.reset()
        pipeline = nil
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        isRunning = false
    }

    private func handle(_ frame: CGImage) async {
        lastFrame = frame
        // Önceki kare hâlâ işleniyorsa bu kare atlanır; okuma kareleri biriktirmez.
        guard !processing, let pipeline else { return }
        processing = true
        await pipeline.process(frame, region: settings.region)
        if pipeline.lastError == .needsDownload { translatorStatus = .needsDownload }
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
