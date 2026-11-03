// SPDX-License-Identifier: AGPL-3.0-only

import Foundation
import Network

public struct CommandResult: Equatable, Sendable {
    public let status: Int32
    public let output: String

    public init(status: Int32, output: String) {
        self.status = status
        self.output = output
    }
}

/// Dış komut çalıştıran her şey (gerçekte `ProcessRunner`).
public protocol CommandRunning: Sendable {
    func run(_ executable: String, _ arguments: [String], input: URL?) async throws -> CommandResult
}

public enum DevModeError: Error, Equatable {
    case unreachable, keyServerOff, wrongPassphrase, keyRefused, installFailed
}

/// TV uygulamasını LG'nin geliştirici modu üzerinden kurar ve günceller.
/// Geliştirici modu açık TV 9922 portunda SSH bekler; anahtar Key Server'dan bir kez alınır.
public struct DevModeInstaller: Sendable {
    public static let port: UInt16 = 9922
    static let appInfoPath = "/media/developer/apps/usr/palm/applications/com.couchsubs.tv/appinfo.json"
    static let remotePackage = "/media/developer/temp/couchsubs.ipk"

    private let host: String
    private let keyFile: URL
    private let runner: CommandRunning
    private let pollInterval: Duration
    private let installTimeout: Duration

    public init(host: String, keyFile: URL, runner: CommandRunning,
                pollInterval: Duration = .seconds(2), installTimeout: Duration = .seconds(90)) {
        self.host = host
        self.keyFile = keyFile
        self.runner = runner
        self.pollInterval = pollInterval
        self.installTimeout = installTimeout
    }

    // MARK: - Sürümler

    /// `com.couchsubs.tv_0.6.1_all.ipk` → `0.6.1`
    public static func version(ofPackage name: String) -> String? {
        let parts = name.split(separator: "_")
        guard name.hasSuffix(".ipk"), parts.count >= 3 else { return nil }
        return String(parts[1])
    }

    public static func isNewer(_ a: String, than b: String) -> Bool {
        a.compare(b, options: .numeric) == .orderedDescending
    }

    static func version(fromAppInfo text: String) -> String? {
        guard let found = text.range(of: #""version"\s*:\s*"[^"]+""#, options: .regularExpression) else { return nil }
        return text[found].split(separator: "\"").last.map(String.init)
    }

    // MARK: - Geliştirici modu

    /// TV'de geliştirici modu açık mı? Kapalıysa port yanıt vermez.
    public static func isDevModeOn(host: String, timeout: Duration = .seconds(2)) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
            let once = Once { result in
                connection.cancel()
                continuation.resume(returning: result)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: once.fire(true)
                case .failed, .waiting: once.fire(false)
                default: break
                }
            }
            connection.start(queue: .global(qos: .utility))
            Task {
                try? await Task.sleep(for: timeout)
                once.fire(false)
            }
        }
    }

    static func keyURL(host: String) -> URL { URL(string: "http://\(host):9991/webos_rsa")! }

    /// Key Server'dan anahtarı alır ve TV ekranındaki parolayla çözer.
    public static func fetchKey(host: String, passphrase: String, runner: CommandRunning) async throws -> String {
        var request = URLRequest(url: keyURL(host: host))
        request.timeoutInterval = 5
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { throw DevModeError.keyServerOff }

        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        guard FileManager.default.createFile(atPath: file.path, contents: data, attributes: [.posixPermissions: 0o600]) else {
            throw DevModeError.installFailed
        }
        defer { try? FileManager.default.removeItem(at: file) }
        let result = try await runner.run("/usr/bin/ssh-keygen", ["-q", "-p", "-P", passphrase, "-N", "", "-f", file.path], input: nil)
        guard result.status == 0, let key = try? String(contentsOf: file, encoding: .utf8) else { throw DevModeError.wrongPassphrase }
        return key
    }

    // MARK: - Kurulum

    /// TV'deki sürüm; uygulama kurulu değilse nil.
    public func installedVersion() async throws -> String? {
        let result = try await ssh("cat \(Self.appInfoPath)")
        return Self.version(fromAppInfo: result.output)
    }

    /// Paketi TV'ye yükler, kurulumu başlatır ve TV'de istenen sürüm görünene kadar bekler.
    public func install(package: URL, version: String) async throws {
        let upload = try await ssh("mkdir -p /media/developer/temp && cat > \(Self.remotePackage)", input: package)
        guard upload.status == 0 else { throw DevModeError.installFailed }

        let parameters = "{\"id\":\"com.ares.defaultName\",\"ipkUrl\":\"\(Self.remotePackage)\",\"subscribe\":true}"
        // -n 1: ilk yanıttan sonra çıkar; kurulum TV'de sürer.
        _ = try await ssh("/usr/bin/luna-send-pub -n 1 'luna://com.webos.appInstallService/dev/install' '\(parameters)'")

        let end = ContinuousClock.now + installTimeout
        var installed = false
        while ContinuousClock.now < end {
            if try await installedVersion() == version {
                installed = true
                break
            }
            try await Task.sleep(for: pollInterval)
        }
        _ = try? await ssh("rm -f \(Self.remotePackage)")
        guard installed else { throw DevModeError.installFailed }
    }

    private func ssh(_ command: String, input: URL? = nil) async throws -> CommandResult {
        let result = try await runner.run("/usr/bin/ssh", [
            "-p", String(Self.port), "-i", keyFile.path,
            "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes", "-o", "ConnectTimeout=6", "-o", "LogLevel=ERROR",
            // TV'nin anahtarı her fabrika ayarında değişir ve eski türdedir.
            "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
            "-o", "HostKeyAlgorithms=+ssh-rsa", "-o", "PubkeyAcceptedAlgorithms=+ssh-rsa",
            "prisoner@\(host)", command,
        ], input: input)
        if result.status == 255 {
            throw result.output.contains("Permission denied") ? DevModeError.keyRefused : DevModeError.unreachable
        }
        return result
    }
}

/// Bir sonucu yalnız bir kez bildirir.
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var action: ((Bool) -> Void)?
    init(_ action: @escaping (Bool) -> Void) { self.action = action }
    func fire(_ value: Bool) {
        let current = lock.withLock { () -> ((Bool) -> Void)? in
            defer { action = nil }
            return action
        }
        current?(value)
    }
}

/// Komutları `Process` ile çalıştırır.
public struct ProcessRunner: CommandRunning {
    public init() {}

    public func run(_ executable: String, _ arguments: [String], input: URL?) async throws -> CommandResult {
        try await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            process.standardInput = try input.map { try FileHandle(forReadingFrom: $0) } ?? FileHandle.nullDevice
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return CommandResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
        }.value
    }
}
