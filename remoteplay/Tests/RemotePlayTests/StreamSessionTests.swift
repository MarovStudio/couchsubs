// SPDX-License-Identifier: AGPL-3.0-only

import XCTest
@testable import RemotePlay

final class FrameThrottleTests: XCTestCase {
    func testThirtyFramesPerSecondPassAtMostFourTimes() {
        var clock = Date(timeIntervalSince1970: 0)
        var throttle = FrameThrottle(minInterval: 0.25, now: { clock })
        var passed = 0
        for _ in 0..<30 {
            if throttle.shouldPass() { passed += 1 }
            clock.addTimeInterval(1.0 / 30)
        }
        XCTAssertLessThanOrEqual(passed, 5)
        XCTAssertGreaterThanOrEqual(passed, 4)
    }
}

final class ReconnectPolicyTests: XCTestCase {
    func testBackoffDoublesUpToThirtySeconds() {
        var policy = ReconnectPolicy()
        XCTAssertEqual((0..<7).map { _ in policy.nextDelay() }, [2, 4, 8, 16, 30, 30, 30])
    }

    func testResetStartsOver() {
        var policy = ReconnectPolicy()
        _ = policy.nextDelay(); _ = policy.nextDelay()
        policy.reset()
        XCTAssertEqual(policy.nextDelay(), 2)
    }
}

final class RegisteredConsoleTests: XCTestCase {
    func testWakeCredentialIsHexOfRegistKey() {
        let console = RegisteredConsole(host: "192.168.1.253", name: "PS5", registKey: Data("1a2b3c4d".utf8) + Data(repeating: 0, count: 8),
                                        morning: Data(repeating: 7, count: 16))
        XCTAssertEqual(console.wakeCredential, 0x1a2b3c4d)
    }
}

final class ConsoleSubnetTests: XCTestCase {
    func testSlash24ListsOtherHosts() {
        let hosts = Console.hosts(address: 0xC0A8_010A, netmask: 0xFFFF_FF00)   // 192.168.1.10/24
        XCTAssertEqual(hosts.count, 253)
        XCTAssertEqual(hosts.first, 0xC0A8_0101)
        XCTAssertEqual(hosts.last, 0xC0A8_01FE)
        XCTAssertFalse(hosts.contains(0xC0A8_010A))
    }

    func testLargeNetworksAreSkipped() {
        XCTAssertTrue(Console.hosts(address: 0x0A00_0001, netmask: 0xFFFF_0000).isEmpty)
    }
}
