// SPDX-License-Identifier: AGPL-3.0-only

import CoreGraphics
import CouchSubsCore
import Foundation

/// Altyazıları TV'ye ileten taraf (gerçekte `SubtitleServer`).
protocol SubtitleSending: AnyObject {
    func sendSubtitle(_ text: String, durationMs: Int)
    func clear()
}

extension SubtitleServer: SubtitleSending {}

/// Kare → bölge → yazı tanıma → kararlılık → çeviri → TV.
@MainActor
final class SubtitlePipeline {
    private let reader: TextReader
    private let translator: TextTranslator
    private let server: SubtitleSending
    /// Kareler saniyede ~20 kez okunur; yaklaşık 0,3 sn boş kalan bölge altyazının kalktığı anlamına gelir.
    private var stabilizer = SubtitleStabilizer(emptyFramesToClear: 6)
    private var scheduler: ReadScheduler
    /// Her çeviri isteği sıra numarası alır. Hızlı konuşmada çeviriler sırasız dönebilir:
    /// daha yeni bir satırın çevirisi gösterilmediyse eski satırınki yine gösterilir.
    private var lastRequested = 0
    private var lastShown = 0
    /// Şu an oyun ekranında duran satırın numarası (bölge boşalınca nil).
    private var lineOnScreen: Int?
    /// Okuma durdurulunca artar; önceki oturumdan dönen çeviriler gösterilmez.
    private var session = 0
    private var translations: [Int: Task<Void, Never>] = [:]

    private(set) var lastPair: (source: String, translation: String)?
    private(set) var lastError: TranslatorError?
    var onPair: ((String, String) -> Void)?
    /// Her çeviri denemesinden sonra çağrılır (başarılıysa nil).
    var onTranslationResult: ((TranslatorError?) -> Void)?

    /// `scheduler`: varsayılanı her kareyi okur; uygulama gereksiz okumaları atlayan planı verir.
    init(reader: TextReader, translator: TextTranslator, server: SubtitleSending, scheduler: ReadScheduler = .always) {
        self.reader = reader
        self.translator = translator
        self.server = server
        self.scheduler = scheduler
    }

    /// Okuma çeviriyi beklemez; böylece çeviri sürerken gelen satırlar da yakalanır.
    func process(_ frame: CGImage, region: CropRegion) async {
        // Yazı tanıma uzun sürebilir; arayüz takılmasın diye ana iş parçacığının dışında yapılır.
        let reader = self.reader
        let (area, signature) = await Task.detached(priority: .userInitiated) {
            let area = RegionCropper.crop(frame, to: region)
            return (area, RegionCropper.signature(of: area))
        }.value
        let text: String
        switch scheduler.plan(signature: signature) {
        case .reuse(let last):
            text = last
        case .read(let deep):
            text = await Task.detached(priority: .userInitiated) {
                (try? reader.read(area, deep: deep)) ?? ""
            }.value
            scheduler.record(text)
        }
        switch stabilizer.feed(text) {
        case .none:
            break
        case .clear:
            lineOnScreen = nil
            server.clear()
        case .translate(let source):
            lastRequested += 1
            let number = lastRequested, current = session
            lineOnScreen = number
            translations[number] = Task { [weak self] in
                await self?.translate(source, number: number, session: current)
                self?.translations[number] = nil
            }
        }
    }

    /// Süren bütün çevirilerin bitmesini bekler.
    func waitForTranslations() async {
        while !translations.isEmpty {
            for task in Array(translations.values) { await task.value }
        }
    }

    /// Satır ekrandan kalktıktan sonra gelen çevirinin TV'de kalacağı süre (TV uygulamasıyla aynı kural).
    static func readingTime(for text: String) -> Int {
        min(8000, 2000 + text.count * 60)
    }

    private func translate(_ source: String, number: Int, session current: Int) async {
        do {
            let translated = try await translator.translate(source)
            guard current == session else { return }
            lastError = nil
            onTranslationResult?(nil)
            guard number > lastShown, stabilizer.shouldSend(source: source, translation: translated) else { return }
            lastShown = number
            // Satır hâlâ ekrandaysa kalkınca silinir; kalktıysa okunacak kadar gösterilir.
            server.sendSubtitle(translated, durationMs: number == lineOnScreen ? 15000 : Self.readingTime(for: translated))
            lastPair = (source, translated)
            onPair?(source, translated)
        } catch {
            guard current == session else { return }
            // Dil paketi eksikse ya da geçici bir hata olduysa satır ekranda kaldıkça yeniden denenir.
            lastError = error as? TranslatorError
            onTranslationResult?(lastError)
            if number == lineOnScreen { stabilizer.forgetSent() }
        }
    }

    /// Okumanın hemen başlaması için modelleri önceden yükler; ilk okuma yoksa saniyelerce sürer.
    func warmUp() {
        let reader = self.reader
        Task.detached(priority: .utility) {
            let context = CGContext(data: nil, width: 64, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            if let image = context?.makeImage() { _ = try? reader.read(image) }
        }
        let translator = self.translator
        Task { _ = try? await translator.translate("Hello") }
    }

    /// Okuma durunca TV'deki son altyazıyı kaldırır.
    func reset() {
        session += 1
        lineOnScreen = nil
        scheduler.reset()
        if stabilizer.reset() == .clear { server.clear() }
    }
}
