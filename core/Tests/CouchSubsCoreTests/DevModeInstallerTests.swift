// SPDX-License-Identifier: AGPL-3.0-only

import XCTest
@testable import CouchSubsCore

final class DevModeInstallerTests: XCTestCase {
    final class FakeRunner: CommandRunning, @unchecked Sendable {
        var calls: [(executable: String, arguments: [String], input: URL?)] = []
        var answers: [(String) -> CommandResult?] = []
        func run(_ executable: String, _ arguments: [String], input: URL?) async throws -> CommandResult {
            calls.append((executable, arguments, input))
            let line = arguments.joined(separator: " ")
            for answer in answers { if let result = answer(line) { return result } }
            return CommandResult(status: 0, output: "")
        }
    }

    private func installer(_ runner: FakeRunner) -> DevModeInstaller {
        DevModeInstaller(host: "192.168.1.230", keyFile: URL(fileURLWithPath: "/tmp/key"), runner: runner,
                         pollInterval: .milliseconds(1), installTimeout: .milliseconds(200))
    }

    func testVersionIsReadFromThePackageName() {
        XCTAssertEqual(DevModeInstaller.version(ofPackage: "com.couchsubs.tv_0.6.1_all.ipk"), "0.6.1")
        XCTAssertNil(DevModeInstaller.version(ofPackage: "notes.txt"))
    }

    func testVersionComparisonIsNumeric() {
        XCTAssertTrue(DevModeInstaller.isNewer("0.10.0", than: "0.9.9"))
        XCTAssertTrue(DevModeInstaller.isNewer("0.6.1", than: "0.4.0"))
        XCTAssertFalse(DevModeInstaller.isNewer("0.6.1", than: "0.6.1"))
        XCTAssertFalse(DevModeInstaller.isNewer("0.6.0", than: "0.6.1"))
    }

    func testVersionIsReadFromAppInfo() {
        XCTAssertEqual(DevModeInstaller.version(fromAppInfo: "{\n  \"id\": \"x\",\n  \"version\": \"0.4.0\"\n}"), "0.4.0")
        XCTAssertNil(DevModeInstaller.version(fromAppInfo: "cat: can't open"))
    }

    func testMissingAppHasNoVersion() async throws {
        let runner = FakeRunner()
        runner.answers = [{ _ in CommandResult(status: 1, output: "No such file") }]
        let version = try await installer(runner).installedVersion()
        XCTAssertNil(version)
    }

    func testRefusedKeyIsReportedAsAnAuthorizationProblem() async {
        let runner = FakeRunner()
        runner.answers = [{ _ in CommandResult(status: 255, output: "prisoner@tv: Permission denied (publickey).") }]
        do {
            _ = try await installer(runner).installedVersion()
            XCTFail("Hata bekleniyordu")
        } catch {
            XCTAssertEqual(error as? DevModeError, .keyRefused)
        }
    }

    func testUnreachableTVIsReportedSeparately() async {
        let runner = FakeRunner()
        runner.answers = [{ _ in CommandResult(status: 255, output: "ssh: connect to host port 9922: Operation timed out") }]
        do {
            _ = try await installer(runner).installedVersion()
            XCTFail("Hata bekleniyordu")
        } catch {
            XCTAssertEqual(error as? DevModeError, .unreachable)
        }
    }

    func testInstallUploadsThenAsksTheTVToInstallAndWaitsForTheVersion() async throws {
        let runner = FakeRunner()
        var reads = 0
        runner.answers = [{ line in
            guard line.contains("appinfo.json") else { return nil }
            reads += 1
            return CommandResult(status: 0, output: reads < 3 ? "\"version\": \"0.4.0\"" : "\"version\": \"0.6.1\"")
        }]
        let package = URL(fileURLWithPath: "/tmp/com.couchsubs.tv_0.6.1_all.ipk")
        try await installer(runner).install(package: package, version: "0.6.1")

        XCTAssertEqual(runner.calls[0].input, package)
        XCTAssertTrue(runner.calls[0].arguments.last!.contains("cat > /media/developer/temp/couchsubs.ipk"))
        XCTAssertTrue(runner.calls[1].arguments.last!.contains("luna://com.webos.appInstallService/dev/install"))
        XCTAssertTrue(runner.calls[1].arguments.last!.contains("/media/developer/temp/couchsubs.ipk"))
        XCTAssertTrue(runner.calls.last!.arguments.last!.contains("rm -f /media/developer/temp/couchsubs.ipk"))
    }

    func testInstallTimesOutWhenTheVersionNeverChanges() async {
        let runner = FakeRunner()
        runner.answers = [{ line in line.contains("appinfo.json") ? CommandResult(status: 0, output: "\"version\": \"0.4.0\"") : nil }]
        do {
            try await installer(runner).install(package: URL(fileURLWithPath: "/tmp/a.ipk"), version: "0.6.1")
            XCTFail("Hata bekleniyordu")
        } catch {
            XCTAssertEqual(error as? DevModeError, .installFailed)
        }
    }

    func testFailedUploadStopsBeforeInstalling() async {
        let runner = FakeRunner()
        runner.answers = [{ line in line.contains("cat >") ? CommandResult(status: 1, output: "disk full") : nil }]
        do {
            try await installer(runner).install(package: URL(fileURLWithPath: "/tmp/a.ipk"), version: "0.6.1")
            XCTFail("Hata bekleniyordu")
        } catch {
            XCTAssertEqual(error as? DevModeError, .installFailed)
        }
        XCTAssertFalse(runner.calls.contains { $0.arguments.last!.contains("appInstallService") })
    }

    func testSshUsesTheTVPortKeyAndOldKeyTypes() async throws {
        let runner = FakeRunner()
        _ = try await installer(runner).installedVersion()
        let arguments = runner.calls[0].arguments
        XCTAssertEqual(runner.calls[0].executable, "/usr/bin/ssh")
        XCTAssertTrue(arguments.contains("9922"))
        XCTAssertTrue(arguments.contains("/tmp/key"))
        XCTAssertTrue(arguments.contains("BatchMode=yes"))
        XCTAssertTrue(arguments.contains("PubkeyAcceptedAlgorithms=+ssh-rsa"))
        XCTAssertTrue(arguments.contains("prisoner@192.168.1.230"))
    }

    func testRemainingSessionTimeIsReadFromLGsReply() {
        XCTAssertEqual(DevModeInstaller.remainingHours(#"{"result":"success","errorCode":"200","errorMsg":"999:58:40"}"#), 999)
        XCTAssertNil(DevModeInstaller.remainingHours(#"{"result":"fail"}"#))
    }

    func testRenewalAddressCarriesTheSessionToken() {
        XCTAssertEqual(DevModeInstaller.renewURL(token: "ab12").absoluteString,
                       "https://developer.lge.com/secure/ResetDevModeSession.dev?sessionToken=ab12")
    }

    func testKeyServerAddress() {
        XCTAssertEqual(DevModeInstaller.keyURL(host: "192.168.1.230").absoluteString, "http://192.168.1.230:9991/webos_rsa")
    }
}
