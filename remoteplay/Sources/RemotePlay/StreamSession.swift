// SPDX-License-Identifier: AGPL-3.0-only

import CChiaki
import CoreGraphics
import Foundation

/// Saniyede en fazla belirli sayıda karenin geçmesine izin verir.
struct FrameThrottle {
    let minInterval: TimeInterval
    let now: () -> Date
    private var last: Date?

    init(minInterval: TimeInterval, now: @escaping () -> Date = Date.init) {
        self.minInterval = minInterval
        self.now = now
    }

    mutating func shouldPass() -> Bool {
        let current = now()
        if let last, current.timeIntervalSince(last) < minInterval { return false }
        last = current
        return true
    }
}

/// Bağlantı koptuğunda yeniden deneme aralıkları: 2, 4, 8, 16, en çok 30 sn.
struct ReconnectPolicy {
    private var attempt = 0

    mutating func nextDelay() -> Int {
        defer { attempt += 1 }
        return min(30, 2 << attempt)
    }

    mutating func reset() { attempt = 0 }
}

public enum SessionState: Equatable, Sendable {
    case connecting
    case streaming
    case disconnected(reason: String)
}

/// PS5'e (ikinci hesapla) Remote Play bağlantısı kurar ve görüntüyü kare kare verir.
/// Ses kapalıdır, kol girdisi gönderilmez. Bağlantı koparsa kendiliğinden yeniden bağlanır.
public final class StreamSession: @unchecked Sendable {
    public var onFrame: ((CGImage) -> Void)?
    public var onState: ((SessionState) -> Void)?

    private let console: RegisteredConsole
    private let accountId: Data
    private let queue = DispatchQueue(label: "couchsubs.stream-session")
    private let decodeQueue = DispatchQueue(label: "couchsubs.decode")
    private let logger = ChiakiLogger()
    private let decoder = H264FrameDecoder()
    private var throttle = FrameThrottle(minInterval: 0.25)
    private var policy = ReconnectPolicy()
    private var session: UnsafeMutablePointer<ChiakiSession>?
    private var hostPointer: UnsafeMutablePointer<CChar>?
    private var wantsToRun = false

    public init(console: RegisteredConsole, accountId: Data) {
        self.console = console
        self.accountId = accountId
    }

    deinit {
        stop()
    }

    public func start() {
        queue.async {
            self.wantsToRun = true
            self.policy.reset()
            self.connect()
        }
    }

    public func stop() {
        queue.sync {
            wantsToRun = false
            tearDown()
        }
    }

    /// Mac uykudan uyandığında ya da ağ değiştiğinde uygulama tarafından çağrılır.
    public func reconnectNow() {
        queue.async {
            guard self.wantsToRun else { return }
            self.tearDown()
            self.policy.reset()
            self.connect()
        }
    }

    // MARK: - Bağlantı

    private func connect() {
        guard wantsToRun, session == nil else { return }
        emit(.connecting)

        // PS5 uyuyorsa uyandır ve uyanmasını bekle (en çok 20 sn).
        let consoles = Self.blockingDiscover(timeout: 2, host: console.host)
        if let info = consoles.first(where: { $0.host == console.host }), !info.isAwake {
            try? Console.wake(console)
            let deadline = Date().addingTimeInterval(20)
            var awake = false
            while Date() < deadline, wantsToRun {
                if Self.blockingDiscover(timeout: 2, host: console.host).contains(where: { $0.host == console.host && $0.isAwake }) { awake = true; break }
            }
            if !awake { return scheduleReconnect(reason: "console-asleep") }
        }

        let session = UnsafeMutablePointer<ChiakiSession>.allocate(capacity: 1)
        hostPointer = strdup(console.host)

        var info = ChiakiConnectInfo()
        info.ps5 = true
        info.host = UnsafePointer(hostPointer)
        copy(console.registKey, into: &info.regist_key)
        copy(console.morning, into: &info.morning)
        chiaki_connect_video_profile_preset(&info.video_profile, CHIAKI_VIDEO_RESOLUTION_PRESET_1080p, CHIAKI_VIDEO_FPS_PRESET_30)
        info.video_profile.codec = CHIAKI_CODEC_H264
        info.video_profile_auto_downgrade = true
        info.enable_keyboard = false
        info.enable_dualsense = false
        info.audio_video_disabled = CHIAKI_AUDIO_DISABLED
        info.auto_regist = false
        info.holepunch_session = nil
        info.rudp_sock = nil
        copy(accountId, into: &info.psn_account_id)
        info.packet_loss_max = 0.05
        info.enable_idr_on_fec_failure = true

        let error = chiaki_session_init(session, &info, logger.pointer)
        guard error.isSuccess else {
            session.deallocate()
            return scheduleReconnect(reason: ChiakiError(code: error).description)
        }

        let user = Unmanaged.passUnretained(self).toOpaque()
        chiaki_session_set_event_cb(session, { event, user in
            guard let event, let user else { return }
            Unmanaged<StreamSession>.fromOpaque(user).takeUnretainedValue().handle(event.pointee)
        }, user)
        chiaki_session_set_video_sample_cb(session, { buffer, size, _, _, user in
            guard let buffer, let user else { return true }
            Unmanaged<StreamSession>.fromOpaque(user).takeUnretainedValue().ingest(Data(bytes: buffer, count: size))
            return true
        }, user)

        let started = chiaki_session_start(session)
        guard started.isSuccess else {
            chiaki_session_fini(session)
            session.deallocate()
            return scheduleReconnect(reason: ChiakiError(code: started).description)
        }
        self.session = session
    }

    private func tearDown() {
        guard let session else { return }
        chiaki_session_stop(session)
        chiaki_session_join(session)
        chiaki_session_fini(session)
        session.deallocate()
        self.session = nil
        free(hostPointer)
        hostPointer = nil
    }

    private func handle(_ event: ChiakiEvent) {
        switch event.type {
        case CHIAKI_EVENT_CONNECTED:
            queue.async { self.policy.reset() }
            emit(.streaming)
        case CHIAKI_EVENT_QUIT:
            let reason = event.quit.reason_str.map { String(cString: $0) } ?? String(cString: chiaki_quit_reason_string(event.quit.reason))
            // Oturum kendi iş parçacığında bitiyor; kapatma ve yeniden bağlanma kendi kuyruğumuzda.
            queue.async {
                self.tearDown()
                self.scheduleReconnect(reason: reason)
            }
        default:
            break
        }
    }

    private func scheduleReconnect(reason: String) {
        emit(.disconnected(reason: reason))
        guard wantsToRun else { return }
        let delay = policy.nextDelay()
        queue.asyncAfter(deadline: .now() + .seconds(delay)) { self.connect() }
    }

    /// Her kare çözülür (sonraki kareler öncekilere dayanır); görüntü saniyede en çok 4 kez üretilir.
    func ingest(_ sample: Data) {
        decodeQueue.async {
            let wanted = self.throttle.shouldPass()
            if let image = self.decoder.decode(annexB: sample, makeImage: wanted), wanted {
                self.onFrame?(image)
            }
        }
    }

    private func emit(_ state: SessionState) {
        onState?(state)
    }

    private static func blockingDiscover(timeout: Double, host: String) -> [ConsoleInfo] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [ConsoleInfo] = []
        Task.detached {
            result = await Console.discover(timeout: .seconds(timeout), host: host)
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
}
