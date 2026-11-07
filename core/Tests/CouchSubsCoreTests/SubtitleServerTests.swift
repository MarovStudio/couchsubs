// SPDX-License-Identifier: AGPL-3.0-only

import XCTest
@testable import CouchSubsCore

final class SubtitleServerTests: XCTestCase {
    private func waitUntil(timeout: TimeInterval = 3, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { XCTFail("Koşul zamanında sağlanmadı"); return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func readLines(_ bytes: URLSession.AsyncBytes, until stop: String) async throws -> [String] {
        var lines: [String] = []
        for try await line in bytes.lines {
            lines.append(line)
            if line == stop { break }
        }
        return lines
    }

    func testStreamsSubtitleAndClearEventsWithCors() async throws {
        let server = SubtitleServer(port: 0)
        let port = try await server.start()
        defer { server.stop() }

        let (bytes, response) = try await URLSession.shared.bytes(from: URL(string: "http://127.0.0.1:\(port)/events")!)
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 200)
        XCTAssertEqual(http.value(forHTTPHeaderField: "Access-Control-Allow-Origin"), "*")
        XCTAssertTrue(http.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("text/event-stream") == true)

        try await waitUntil { server.connectedClients == 1 }
        server.sendSubtitle("Merhaba", durationMs: 4000, box: TextBox(left: 0.25, top: 0.8, right: 0.75, bottom: 0.874_99))
        server.clear()

        let lines = try await readLines(bytes, until: "event: clear")
        XCTAssertTrue(lines.contains("event: subtitle"))
        XCTAssertTrue(lines.contains { $0.hasPrefix("data:") && $0.contains("\"text\":\"Merhaba\"") && $0.contains("\"duration\":4000")
            && $0.contains("\"box\":{\"bottom\":0.875,\"left\":0.25,\"right\":0.75,\"top\":0.8}") })
    }

    func testNewClientReceivesLastStyle() async throws {
        let server = SubtitleServer(port: 0)
        let port = try await server.start()
        defer { server.stop() }
        server.sendStyle(SubtitleStyle(fontSize: 58, bottomPercent: 10, placement: .above, background: 40, bold: true))

        let (bytes, _) = try await URLSession.shared.bytes(from: URL(string: "http://127.0.0.1:\(port)/events")!)
        var sawStyle = false
        for try await line in bytes.lines where line.hasPrefix("data:") {
            sawStyle = line.contains("\"fontSize\":58") && line.contains("\"bottomPercent\":10") && line.contains("\"placement\":\"above\"")
                && line.contains("\"background\":40") && line.contains("\"bold\":true")
            break
        }
        XCTAssertTrue(sawStyle)
    }

    func testClientCountDropsWhenClientDisconnects() async throws {
        let server = SubtitleServer(port: 0)
        let port = try await server.start()
        defer { server.stop() }

        let task = Task {
            let (bytes, _) = try await URLSession.shared.bytes(from: URL(string: "http://127.0.0.1:\(port)/events")!)
            for try await _ in bytes.lines {}
        }
        try await waitUntil { server.connectedClients == 1 }
        task.cancel()
        try await waitUntil { server.connectedClients == 0 }
    }

    func testHelloIdentifiesTheApp() async throws {
        let server = SubtitleServer(port: 0)
        let port = try await server.start()
        defer { server.stop() }
        let (data, response) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/hello")!)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Access-Control-Allow-Origin"), "*")
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"app":"couchsubs"}"#)
    }

    func testUnknownPathIs404() async throws {
        let server = SubtitleServer(port: 0)
        let port = try await server.start()
        defer { server.stop() }

        let (_, response) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/nope")!)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 404)
    }

    func testOldSavedStyleGetsNewDefaults() throws {
        let style = try JSONDecoder().decode(SubtitleStyle.self, from: Data(#"{"fontSize":58,"bottomPercent":12}"#.utf8))
        XCTAssertEqual(style, SubtitleStyle(fontSize: 58, bottomPercent: 12, placement: .cover, background: 72, bold: false))
    }
}
