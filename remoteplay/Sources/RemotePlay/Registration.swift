// SPDX-License-Identifier: AGPL-3.0-only

import CChiaki
import Foundation

/// PS5'e kaydedilmiş bu cihazın bağlantı bilgileri. Anahtarlıkta saklanır.
public struct RegisteredConsole: Codable, Equatable, Sendable {
    public let host: String
    public let name: String
    /// 16 baytlık kayıt anahtarı (ASCII onaltılık, sıfırla doldurulmuş).
    public let registKey: Data
    /// 16 baytlık oturum anahtarı ("morning").
    public let morning: Data

    public init(host: String, name: String, registKey: Data, morning: Data) {
        self.host = host
        self.name = name
        self.registKey = registKey
        self.morning = morning
    }

    /// Uyandırma için kayıt anahtarının onaltılık değeri.
    public var wakeCredential: UInt64? {
        let end = registKey.firstIndex(of: 0) ?? registKey.endIndex
        return UInt64(String(decoding: registKey[..<end], as: UTF8.self), radix: 16)
    }

    func withHost(_ newHost: String) -> RegisteredConsole {
        RegisteredConsole(host: newHost, name: name, registKey: registKey, morning: morning)
    }
}

public enum Registration {
    /// PS5'in "Cihazı Bağla" ekranındaki 8 haneli kodla kayıt olur.
    public static func register(host: String, accountId: Data, pin: UInt32) async throws -> RegisteredConsole {
        let logger = ChiakiLogger()
        let regist = UnsafeMutablePointer<ChiakiRegist>.allocate(capacity: 1)
        let box = Box()
        var started = false
        defer {
            // Kayıt iş parçacığı geri çağrıdan sonra kapanır; beklemeyi ayrı bir kuyrukta yap.
            let wasStarted = started
            DispatchQueue.global().async {
                if wasStarted { chiaki_regist_fini(regist) }
                regist.deallocate()
                withExtendedLifetime(logger) {}
            }
        }

        let console: RegisteredConsole = try await withCheckedThrowingContinuation { continuation in
            box.continuation = continuation
            host.withCString { hostPointer in
                var info = ChiakiRegistInfo()
                info.target = CHIAKI_TARGET_PS5_1
                info.host = hostPointer
                info.broadcast = false
                info.psn_online_id = nil
                copy(accountId, into: &info.psn_account_id)
                info.pin = pin
                info.console_pin = 0
                info.holepunch_info = nil
                info.rudp = nil

                let user = Unmanaged.passRetained(box).toOpaque()
                let error = chiaki_regist_start(regist, logger.pointer, &info, { event, user in
                    guard let event, let user else { return }
                    Unmanaged<Box>.fromOpaque(user).takeRetainedValue().finish(event.pointee)
                }, user)
                if error.isSuccess {
                    started = true
                } else {
                    Unmanaged<Box>.fromOpaque(user).release()
                    box.resume(.failure(ChiakiError(code: error)))
                }
            }
        }
        return console.withHost(host)
    }

    public enum RegistrationError: Error { case failed, canceled }

    private final class Box {
        var continuation: CheckedContinuation<RegisteredConsole, Error>?

        func finish(_ event: ChiakiRegistEvent) {
            switch event.type {
            case CHIAKI_REGIST_EVENT_TYPE_FINISHED_SUCCESS:
                guard let host = event.registered_host?.pointee else { return resume(.failure(RegistrationError.failed)) }
                resume(.success(RegisteredConsole(host: "", name: string(of: host.server_nickname),
                                                  registKey: data(of: host.rp_regist_key), morning: data(of: host.rp_key))))
            case CHIAKI_REGIST_EVENT_TYPE_FINISHED_CANCELED:
                resume(.failure(RegistrationError.canceled))
            default:
                resume(.failure(RegistrationError.failed))
            }
        }

        func resume(_ result: Result<RegisteredConsole, Error>) {
            continuation?.resume(with: result)
            continuation = nil
        }
    }
}
