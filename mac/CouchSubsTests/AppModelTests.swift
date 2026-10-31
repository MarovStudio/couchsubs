// SPDX-License-Identifier: AGPL-3.0-only

import CouchSubsCore
import RemotePlay
import XCTest
@testable import CouchSubs

final class MemoryStore: AppStore {
    var values: [String: Data] = [:]
    func save<T: Encodable>(_ value: T, for key: String) { values[key] = try? JSONEncoder().encode(value) }
    func load<T: Decodable>(_ type: T.Type, for key: String) -> T? { values[key].flatMap { try? JSONDecoder().decode(type, from: $0) } }
    func remove(_ key: String) { values[key] = nil }
}

extension UserDefaults {
    /// Testler gerçek uygulamanın tercihlerine yazmasın diye her model ayrı bir alan kullanır.
    static func isolated() -> UserDefaults { UserDefaults(suiteName: "couchsubs-test-\(UUID())")! }
}

final class FakeServices: AppServices {
    var consoles = [ConsoleInfo(host: "192.168.1.253", name: "PS5-789", isAwake: true)]
    var tvs = [LGTV(name: "LG TV", host: "192.168.1.153")]
    var registered: RegisteredConsole?
    var registerError: Error?
    var launchedServer: String?
    var streams: [FakeStream] = []
    var keepers: [FakeKeeper] = []

    func discoverConsoles() async -> [ConsoleInfo] { consoles }
    func accountId(fromRedirect url: URL) async throws -> Data { Data(repeating: 1, count: 8) }
    func register(host: String, accountId: Data, pin: UInt32) async throws -> RegisteredConsole {
        if let registerError { throw registerError }
        let console = RegisteredConsole(host: host, name: "PS5-789", registKey: Data(repeating: 0x31, count: 16), morning: Data(repeating: 2, count: 16))
        registered = console
        return console
    }
    func discoverTVs() async -> [LGTV] { tvs }
    func pairTV(_ tv: LGTV, key: String?, server: String) async throws -> String {
        launchedServer = server
        return "tv-key"
    }
    func makeStream(console: RegisteredConsole, accountId: Data) -> StreamControlling {
        let stream = FakeStream()
        streams.append(stream)
        return stream
    }
    func makeKeeper(tv: LGTV, key: String?, params: [String: Any]) -> KeeperControlling {
        let keeper = FakeKeeper()
        keepers.append(keeper)
        return keeper
    }
}

final class FakeStream: StreamControlling {
    var onFrame: ((CGImage) -> Void)?
    var onState: ((SessionState) -> Void)?
    var started = false
    func start() { started = true }
    func stop() { started = false }
    func reconnectNow() {}
}

final class FakeKeeper: KeeperControlling {
    var running = false
    func start(interval: Duration) { running = true }
    func stop() { running = false }
    func reconnect() {}
}

@MainActor
final class AppModelTests: XCTestCase {
    private let console = RegisteredConsole(host: "192.168.1.253", name: "PS5", registKey: Data(repeating: 0x31, count: 16), morning: Data(repeating: 2, count: 16))

    func testFreshInstallStartsAtWelcome() {
        let model = AppModel(services: FakeServices(), store: MemoryStore(), defaults: .isolated())
        XCTAssertEqual(model.step, .welcome)
    }

    func testCompleteSetupOpensMainScreen() {
        let store = MemoryStore()
        store.save(Data(repeating: 1, count: 8), for: StoreKey.accountId)
        store.save(console, for: StoreKey.console)
        store.save(LGTV(name: "LG TV", host: "192.168.1.153"), for: StoreKey.tv)
        store.save("tv-key", for: StoreKey.tvKey)
        XCTAssertEqual(AppModel(services: FakeServices(), store: store, defaults: .isolated()).step, .done)
    }

    func testPsnStepNeedsAccountId() {
        let model = AppModel(services: FakeServices(), store: MemoryStore(), defaults: .isolated())
        model.step = .psnLogin
        XCTAssertFalse(model.canAdvance)
        model.accountId = Data(repeating: 1, count: 8)
        XCTAssertTrue(model.canAdvance)
    }

    func testConsoleStepNeedsRegistration() async throws {
        let services = FakeServices()
        let model = AppModel(services: services, store: MemoryStore(), defaults: .isolated())
        model.accountId = Data(repeating: 1, count: 8)
        model.step = .console
        XCTAssertFalse(model.canAdvance)
        try await model.register(host: "192.168.1.253", pin: "12345678")
        XCTAssertTrue(model.canAdvance)
        XCTAssertEqual(services.registered?.host, "192.168.1.253")
    }

    /// PS5 hesabı tanımazsa kullanıcıya kodu hangi kullanıcıdan alacağı söylenmeli.
    func testWrongAccountRegistrationExplainsWhatToDo() async {
        let services = FakeServices()
        services.registerError = Registration.RegistrationError.wrongAccount
        let model = AppModel(services: services, store: MemoryStore(), defaults: .isolated())
        model.accountId = Data(repeating: 1, count: 8)
        do {
            try await model.register(host: "192.168.1.253", pin: "12345678")
            XCTFail("Kayıt başarısız olmalı")
        } catch {
            XCTAssertEqual(error as? AppError, .wrongAccount)
        }
    }

    func testOtherRegistrationFailureSuggestsNewCode() async {
        let services = FakeServices()
        services.registerError = Registration.RegistrationError.failed
        let model = AppModel(services: services, store: MemoryStore(), defaults: .isolated())
        model.accountId = Data(repeating: 1, count: 8)
        do {
            try await model.register(host: "192.168.1.253", pin: "12345678")
            XCTFail("Kayıt başarısız olmalı")
        } catch {
            XCTAssertEqual(error as? AppError, .registrationFailed)
        }
    }

    func testPinMustBeEightDigits() async {
        let model = AppModel(services: FakeServices(), store: MemoryStore(), defaults: .isolated())
        model.accountId = Data(repeating: 1, count: 8)
        do {
            try await model.register(host: "192.168.1.253", pin: "1234")
            XCTFail("Kısa kod kabul edilmemeli")
        } catch {
            XCTAssertNil(model.console)
        }
    }

    func testPairingTvPassesServerAddressAndStoresKey() async throws {
        let services = FakeServices()
        let store = MemoryStore()
        let model = AppModel(services: services, store: store, defaults: .isolated())
        try await model.pair(LGTV(name: "LG TV", host: "192.168.1.153"))
        XCTAssertTrue(services.launchedServer?.hasPrefix("http://") == true)
        XCTAssertTrue(services.launchedServer?.hasSuffix(":\(model.serverPort)") == true)
        XCTAssertEqual(store.load(String.self, for: StoreKey.tvKey), "tv-key")
    }

    func testOnboardingWalksAllStepsInOrder() async throws {
        let model = AppModel(services: FakeServices(), store: MemoryStore(), defaults: .isolated())
        XCTAssertEqual(model.step, .welcome); model.advance()
        XCTAssertEqual(model.step, .secondAccount); model.advance()
        XCTAssertEqual(model.step, .psnLogin)
        try await model.completePSNLogin(redirect: URL(string: "https://remoteplay.dl.playstation.net/remoteplay/redirect?code=x")!)
        model.advance()
        XCTAssertEqual(model.step, .console)
        try await model.register(host: "192.168.1.253", pin: "12345678"); model.advance()
        XCTAssertEqual(model.step, .tv)
        try await model.pair(LGTV(name: "LG TV", host: "192.168.1.153")); model.advance()
        XCTAssertEqual(model.step, .test); model.advance()
        XCTAssertEqual(model.step, .done)
    }
}

@MainActor
final class AppModelRunTests: XCTestCase {
    private func readyModel(_ services: FakeServices) -> AppModel {
        let store = MemoryStore()
        store.save(Data(repeating: 1, count: 8), for: StoreKey.accountId)
        store.save(RegisteredConsole(host: "192.168.1.253", name: "PS5", registKey: Data(repeating: 0x31, count: 16), morning: Data(repeating: 2, count: 16)), for: StoreKey.console)
        store.save(LGTV(name: "LG TV", host: "127.0.0.1"), for: StoreKey.tv)
        store.save("tv-key", for: StoreKey.tvKey)
        return AppModel(services: services, store: store, defaults: .isolated())
    }

    func testDoubleStartCreatesOneSession() async {
        let services = FakeServices()
        let model = readyModel(services)
        async let first: Void = model.start()
        async let second: Void = model.start()
        _ = await (first, second)
        XCTAssertEqual(services.streams.count, 1)
        XCTAssertEqual(services.keepers.count, 1)
        XCTAssertTrue(model.isRunning)
        model.stop()
    }

    func testRunningPreventsIdleSleep() async {
        let model = readyModel(FakeServices())
        await model.start()
        XCTAssertTrue(model.isPreventingSleep)
        model.stop()
        XCTAssertFalse(model.isPreventingSleep)
    }

    func testDisconnectClearsSubtitleOnTV() async throws {
        let services = FakeServices()
        let model = readyModel(services)
        await model.start()
        defer { model.stop() }
        let (bytes, _) = try await URLSession.shared.bytes(from: URL(string: "http://127.0.0.1:\(model.serverPort)/events")!)
        try await Task.sleep(nanoseconds: 200_000_000)
        services.streams[0].onState?(.disconnected(.network))
        var sawClear = false
        for try await line in bytes.lines where line == "event: clear" { sawClear = true; break }
        XCTAssertTrue(sawClear)
    }

    func testTranslatorStatusFollowsPipeline() {
        XCTAssertEqual(AppModel.translatorStatus(after: nil), .ready)
        XCTAssertEqual(AppModel.translatorStatus(after: .needsDownload), .needsDownload)
        XCTAssertEqual(AppModel.translatorStatus(after: .unsupported), .unsupported)
    }

    func testSettingsGoToPreferencesNotKeychain() {
        let store = MemoryStore()
        let defaults = UserDefaults(suiteName: "couchsubs-test-\(UUID())")!
        let model = AppModel(services: FakeServices(), store: store, defaults: defaults)
        model.settings.style.fontSize = 58
        XCTAssertNil(store.values[StoreKey.settings])
        XCTAssertEqual(AppModel(services: FakeServices(), store: store, defaults: defaults).settings.style.fontSize, 58)
    }

    func testChangingLanguageWhileRunningRebuildsPipeline() async {
        let model = readyModel(FakeServices())
        await model.start()
        defer { model.stop() }
        XCTAssertEqual(model.activeLanguages?.source, "en")
        model.settings.sourceLanguage = "ja"
        XCTAssertEqual(model.activeLanguages?.source, "ja")
    }

    func testLoginPasscodeIsExplained() {
        XCTAssertEqual(AppModel.statusText(.disconnected(.loginPasscode), running: true),
                       String(localized: "The second user has a login passcode on the PS5. Turn it off in Settings › Users and Accounts."))
    }

    func testDisconnectReasonsAreExplained() {
        XCTAssertEqual(AppModel.statusText(.disconnected(.consoleAsleep), running: true), String(localized: "Turn on your PS5"))
        XCTAssertEqual(AppModel.statusText(.disconnected(.inUse), running: true), String(localized: "Remote Play is in use on another device"))
        XCTAssertEqual(AppModel.statusText(.disconnected(.refused), running: true), String(localized: "The PS5 refused the connection. Set up the PS5 again."))
        XCTAssertEqual(AppModel.statusText(.disconnected(.network), running: true), String(localized: "Reconnecting…"))
        XCTAssertEqual(AppModel.statusText(.disconnected(.stopped), running: false), String(localized: "Not connected"))
    }
}

final class LocalizationTests: XCTestCase {
    private func strings(_ language: String) throws -> [String: String] {
        let bundle = Bundle(for: AppModel.self)
        let path = try XCTUnwrap(bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language), language)
        return try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
    }

    func testTurkishCoversEveryEnglishKey() throws {
        let english = try strings("en"), turkish = try strings("tr")
        XCTAssertFalse(english.isEmpty)
        XCTAssertEqual(Set(english.keys).subtracting(turkish.keys), [])
        XCTAssertTrue(turkish.values.allSatisfy { !$0.isEmpty })
    }
}
