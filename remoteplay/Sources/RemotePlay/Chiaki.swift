// SPDX-License-Identifier: AGPL-3.0-only

import CChiaki
import Foundation

/// libchiaki'nin günlüğünü uygulamanın günlüğüne yönlendirir (hata ve uyarılar).
final class ChiakiLogger {
    let pointer: UnsafeMutablePointer<ChiakiLog>
    /// Her satır için çağrılır (libchiaki'nin iş parçacığında).
    var onMessage: ((String) -> Void)?

    init() {
        pointer = .allocate(capacity: 1)
        let mask = UInt32(CHIAKI_LOG_ERROR.rawValue | CHIAKI_LOG_WARNING.rawValue | CHIAKI_LOG_INFO.rawValue)
        chiaki_log_init(pointer, mask, { level, message, user in
            guard let message else { return }
            let text = String(cString: message)
            print("[chiaki] \(text)")
            if let user { Unmanaged<ChiakiLogger>.fromOpaque(user).takeUnretainedValue().onMessage?(text) }
        }, nil)
        // Günlük yapısı bu nesneyle birlikte yaşar; geri çağrıya sahibini sahiplenmeden ver.
        pointer.pointee.user = Unmanaged.passUnretained(self).toOpaque()
    }

    deinit { pointer.deallocate() }
}

extension ChiakiErrorCode {
    var isSuccess: Bool { self == CHIAKI_ERR_SUCCESS }
}

public struct ChiakiError: Error, CustomStringConvertible {
    public let code: ChiakiErrorCode
    public var description: String { String(cString: chiaki_error_string(code)) }
}

/// Swift `Data`'yı C dizisi demetine (tuple) kopyalar.
func copy<T>(_ data: Data, into tuple: inout T) {
    withUnsafeMutableBytes(of: &tuple) { destination in
        destination.initializeMemory(as: UInt8.self, repeating: 0)
        data.prefix(destination.count).withUnsafeBytes { destination.copyMemory(from: UnsafeRawBufferPointer(rebasing: $0[...])) }
    }
}

/// C dizisi demetini `Data`'ya çevirir.
func data<T>(of tuple: T) -> Data {
    withUnsafeBytes(of: tuple) { Data($0) }
}

/// Sıfırla biten C dizgesi demetini `String`'e çevirir.
func string<T>(of tuple: T) -> String {
    let bytes = data(of: tuple)
    let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
    return String(decoding: bytes[..<end], as: UTF8.self)
}
