// SPDX-License-Identifier: AGPL-3.0-only

import Network
import XCTest
@testable import CouchSubsCore

/// SSAP konuşan sahte bir TV: register'a client-key ile, isteklere sırayla verilen yanıtlarla döner.
final class FakeLGTV: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "fake-lgtv")
    private(set) var receivedURIs: [String] = []
    private(set) var receivedPayloads: [[String: Any]] = []
    var foregroundApps: [String] = []

    init() throws {
        let parameters = NWParameters.tcp
        parameters.defaultProtocolStack.applicationProtocols.insert(NWProtocolWebSocket.Options(), at: 0)
        listener = try NWListener(using: parameters, on: .any)
    }

    func start() async -> UInt16 {
        await withCheckedContinuation { continuation in
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                connection.start(queue: self.queue)
                self.receive(on: connection)
            }
            listener.stateUpdateHandler = { [listener] state in
                if case .ready = state { continuation.resume(returning: listener.port!.rawValue) }
            }
            listener.start(queue: queue)
        }
    }

    func stop() { listener.cancel() }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self, error == nil, let data,
                  let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            self.handle(message, on: connection)
            self.receive(on: connection)
        }
    }

    private func handle(_ message: [String: Any], on connection: NWConnection) {
        let id = message["id"] as? String ?? ""
        if message["type"] as? String == "register" {
            send(["type": "response", "id": id, "payload": ["pairingType": "PROMPT", "returnValue": true]], on: connection)
            send(["type": "registered", "id": id, "payload": ["client-key": "fake-key"]], on: connection)
            return
        }
        let uri = message["uri"] as? String ?? ""
        receivedURIs.append(uri)
        receivedPayloads.append(message["payload"] as? [String: Any] ?? [:])
        var payload: [String: Any] = ["returnValue": true]
        if uri.hasSuffix("getForegroundAppInfo") {
            payload["appId"] = foregroundApps.isEmpty ? "" : foregroundApps.removeFirst()
        }
        send(["type": "response", "id": id, "payload": payload], on: connection)
    }

    private func send(_ object: [String: Any], on connection: NWConnection) {
        let data = try! JSONSerialization.data(withJSONObject: object)
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "send", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { _ in })
    }
}

final class SSAPClientTests: XCTestCase {
    func testConnectReturnsClientKeyAndLaunchSendsUri() async throws {
        let tv = try FakeLGTV()
        let port = await tv.start()
        defer { tv.stop() }

        let client = SSAPClient(endpoints: [URL(string: "ws://127.0.0.1:\(port)")!], clientKey: nil)
        let key = try await client.connect()
        XCTAssertEqual(key, "fake-key")

        try await client.launch(appId: "com.couchsubs.tv", params: ["server": "http://1.2.3.4:8787"])
        XCTAssertEqual(tv.receivedURIs.last, "ssap://system.launcher/launch")
        XCTAssertEqual(tv.receivedPayloads.last?["id"] as? String, "com.couchsubs.tv")
        client.close()
    }

    func testForegroundAppId() async throws {
        let tv = try FakeLGTV()
        tv.foregroundApps = ["com.webos.app.hdmi2"]
        let port = await tv.start()
        defer { tv.stop() }

        let client = SSAPClient(endpoints: [URL(string: "ws://127.0.0.1:\(port)")!], clientKey: "fake-key")
        _ = try await client.connect()
        let app = try await client.foregroundAppId()
        XCTAssertEqual(app, "com.webos.app.hdmi2")
        client.close()
    }

    func testFallsBackToNextEndpoint() async throws {
        let tv = try FakeLGTV()
        let port = await tv.start()
        defer { tv.stop() }

        // İlk adreste kimse dinlemiyor; ikinciye düşmeli.
        let client = SSAPClient(endpoints: [URL(string: "ws://127.0.0.1:1")!, URL(string: "ws://127.0.0.1:\(port)")!], clientKey: nil)
        let key = try await client.connect()
        XCTAssertEqual(key, "fake-key")
        client.close()
    }
}

final class TVKeeperTests: XCTestCase {
    final class FakeControl: TVControlling, @unchecked Sendable {
        var foreground: [String]
        var launches: [(String, [String: String])] = []
        init(foreground: [String]) { self.foreground = foreground }
        func foregroundAppId() async throws -> String { foreground.isEmpty ? "" : foreground.removeFirst() }
        func launch(appId: String, params: [String: Any]) async throws {
            launches.append((appId, params.compactMapValues { $0 as? String }))
        }
    }

    func testRelaunchesOnlyWhenAnotherAppIsInFront() async throws {
        let control = FakeControl(foreground: ["com.webos.app.hdmi2", "com.couchsubs.tv", "com.couchsubs.tv"])
        let keeper = TVKeeper(control: control, appId: "com.couchsubs.tv", params: ["server": "http://1.2.3.4:8787"])
        try await keeper.tick()
        try await keeper.tick()
        try await keeper.tick()
        XCTAssertEqual(control.launches.count, 1)
        XCTAssertEqual(control.launches.first?.0, "com.couchsubs.tv")
        XCTAssertEqual(control.launches.first?.1["server"], "http://1.2.3.4:8787")
    }
}
