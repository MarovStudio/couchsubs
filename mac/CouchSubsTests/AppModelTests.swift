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

final class FakeServices: AppServices {
    var consoles = [ConsoleInfo(host: "192.168.1.253", name: "PS5-789", isAwake: true)]
    var tvs = [LGTV(name: "LG TV", host: "192.168.1.153")]
    var registered: RegisteredConsole?
    var launchedServer: String?

    func discoverConsoles() async -> [ConsoleInfo] { consoles }
    func accountId(fromRedirect url: URL) async throws -> Data { Data(repeating: 1, count: 8) }
    func register(host: String, accountId: Data, pin: UInt32) async throws -> RegisteredConsole {
        let console = RegisteredConsole(host: host, name: "PS5-789", registKey: Data(repeating: 0x31, count: 16), morning: Data(repeating: 2, count: 16))
        registered = console
        return console
    }
    func discoverTVs() async -> [LGTV] { tvs }
    func pairTV(_ tv: LGTV, key: String?, server: String) async throws -> String {
        launchedServer = server
        return "tv-key"
    }
}

@MainActor
final class AppModelTests: XCTestCase {
    private let console = RegisteredConsole(host: "192.168.1.253", name: "PS5", registKey: Data(repeating: 0x31, count: 16), morning: Data(repeating: 2, count: 16))

    func testFreshInstallStartsAtWelcome() {
        let model = AppModel(services: FakeServices(), store: MemoryStore())
        XCTAssertEqual(model.step, .welcome)
    }

    func testCompleteSetupOpensMainScreen() {
        let store = MemoryStore()
        store.save(Data(repeating: 1, count: 8), for: StoreKey.accountId)
        store.save(console, for: StoreKey.console)
        store.save(LGTV(name: "LG TV", host: "192.168.1.153"), for: StoreKey.tv)
        store.save("tv-key", for: StoreKey.tvKey)
        XCTAssertEqual(AppModel(services: FakeServices(), store: store).step, .done)
    }

    func testPsnStepNeedsAccountId() {
        let model = AppModel(services: FakeServices(), store: MemoryStore())
        model.step = .psnLogin
        XCTAssertFalse(model.canAdvance)
        model.accountId = Data(repeating: 1, count: 8)
        XCTAssertTrue(model.canAdvance)
    }

    func testConsoleStepNeedsRegistration() async throws {
        let services = FakeServices()
        let model = AppModel(services: services, store: MemoryStore())
        model.accountId = Data(repeating: 1, count: 8)
        model.step = .console
        XCTAssertFalse(model.canAdvance)
        try await model.register(host: "192.168.1.253", pin: "12345678")
        XCTAssertTrue(model.canAdvance)
        XCTAssertEqual(services.registered?.host, "192.168.1.253")
    }

    func testPinMustBeEightDigits() async {
        let model = AppModel(services: FakeServices(), store: MemoryStore())
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
        let model = AppModel(services: services, store: store)
        try await model.pair(LGTV(name: "LG TV", host: "192.168.1.153"))
        XCTAssertTrue(services.launchedServer?.hasPrefix("http://") == true)
        XCTAssertTrue(services.launchedServer?.hasSuffix(":\(model.serverPort)") == true)
        XCTAssertEqual(store.load(String.self, for: StoreKey.tvKey), "tv-key")
    }

    func testOnboardingWalksAllStepsInOrder() async throws {
        let model = AppModel(services: FakeServices(), store: MemoryStore())
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
