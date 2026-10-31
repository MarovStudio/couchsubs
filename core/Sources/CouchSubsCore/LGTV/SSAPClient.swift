// SPDX-License-Identifier: AGPL-3.0-only

import Foundation

public struct LGTV: Codable, Hashable, Sendable {
    public let name: String
    public let host: String

    public init(name: String, host: String) {
        self.name = name
        self.host = host
    }
}

/// TV'de uygulama başlatabilen ve önplandaki uygulamayı söyleyebilen her şey.
public protocol TVControlling: AnyObject {
    func launch(appId: String, params: [String: Any]) async throws
    func foregroundAppId() async throws -> String
}

/// LG TV ile SSAP (WebSocket) üzerinden konuşur. İlk bağlantıda TV ekranında izin sorulur;
/// dönen client-key saklanırsa sonraki bağlantılar sorusuz olur.
public final class SSAPClient: NSObject, TVControlling, URLSessionDelegate, @unchecked Sendable {
    public enum SSAPError: Error { case cannotConnect, rejected(String), badResponse }

    private let endpoints: [URL]
    private var clientKey: String?
    private var session: URLSession!
    private var socket: URLSessionWebSocketTask?
    private var nextId = 1

    /// Önce şifreli (3001), olmazsa düz (3000) bağlantı denenir; eski webOS'lar yalnız 3000'i açar.
    public convenience init(tv: LGTV, clientKey: String?) {
        self.init(endpoints: [URL(string: "wss://\(tv.host):3001")!, URL(string: "ws://\(tv.host):3000")!], clientKey: clientKey)
    }

    init(endpoints: [URL], clientKey: String?) {
        self.endpoints = endpoints
        self.clientKey = clientKey
        super.init()
        session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    }

    /// Eşleşir ve client-key'i döner. Kullanıcı TV'de onay verene kadar bekler (en çok 60 sn).
    public func connect() async throws -> String {
        for url in endpoints {
            let task = session.webSocketTask(with: url)
            task.resume()
            do {
                try await task.send(.data(SSAPMessages.register(clientKey: clientKey)))
                let key = try await waitForRegistration(on: task)
                socket = task
                clientKey = key
                return key
            } catch SSAPError.rejected(let reason) {
                task.cancel()
                throw SSAPError.rejected(reason)
            } catch {
                task.cancel()
            }
        }
        throw SSAPError.cannotConnect
    }

    public func close() {
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
    }

    public func launch(appId: String, params: [String: Any]) async throws {
        let response = try await request("ssap://system.launcher/launch", payload: ["id": appId, "params": params])
        if response["returnValue"] as? Bool == false { throw SSAPError.rejected(response["errorText"] as? String ?? "launch") }
    }

    public func foregroundAppId() async throws -> String {
        let response = try await request("ssap://com.webos.applicationManager/getForegroundAppInfo", payload: nil)
        return response["appId"] as? String ?? ""
    }

    // MARK: - İç işleyiş

    private func waitForRegistration(on task: URLSessionWebSocketTask) async throws -> String {
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            let message = try await Self.decode(task.receive())
            switch message["type"] as? String {
            case "registered":
                guard let key = (message["payload"] as? [String: Any])?["client-key"] as? String else { throw SSAPError.badResponse }
                return key
            case "error":
                throw SSAPError.rejected(message["error"] as? String ?? "register")
            default:
                continue // "response" (TV soruyu gösterdi), onay bekleniyor
            }
        }
        throw SSAPError.rejected("timeout")
    }

    private func request(_ uri: String, payload: [String: Any]?) async throws -> [String: Any] {
        guard let socket else { throw SSAPError.cannotConnect }
        let id = "req_\(nextId)"
        nextId += 1
        try await socket.send(.data(SSAPMessages.request(id: id, uri: uri, payload: payload)))
        while true {
            let message = try await Self.decode(socket.receive())
            guard message["id"] as? String == id else { continue }
            if message["type"] as? String == "error" { throw SSAPError.rejected(message["error"] as? String ?? uri) }
            return message["payload"] as? [String: Any] ?? [:]
        }
    }

    private static func decode(_ message: URLSessionWebSocketTask.Message) throws -> [String: Any] {
        let data: Data
        switch message {
        case .data(let d): data = d
        case .string(let s): data = Data(s.utf8)
        @unknown default: throw SSAPError.badResponse
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw SSAPError.badResponse }
        return object
    }

    /// TV'nin 3001 portundaki sertifikası kendinden imzalıdır; yalnız bu TV'nin adresi için kabul edilir.
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async
        -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let host = challenge.protectionSpace.host
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              endpoints.contains(where: { $0.host == host }),
              let trust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }
}

/// TV kendi HDMI girişine geçerse (SimpLink/CEC) TV uygulamasını yeniden öne getirir.
public final class TVKeeper: @unchecked Sendable {
    private let control: TVControlling
    private let appId: String
    private let params: [String: Any]
    private var loop: Task<Void, Never>?

    public init(control: TVControlling, appId: String, params: [String: Any]) {
        self.control = control
        self.appId = appId
        self.params = params
    }

    /// Bir kontrol: önde başka uygulama varsa bizimkini başlatır.
    public func tick() async throws {
        let current = try await control.foregroundAppId()
        if current != appId { try await control.launch(appId: appId, params: params) }
    }

    public func start(interval: Duration = .seconds(5)) {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await self?.tick()
                try? await Task.sleep(for: interval)
            }
        }
    }

    public func stop() {
        loop?.cancel()
        loop = nil
    }
}
