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
    /// Kareler saniyede ~10 kez okunur; yaklaşık 0,4 sn boş kalan bölge altyazının kalktığı anlamına gelir.
    private var stabilizer = SubtitleStabilizer(emptyFramesToClear: 4)
    /// Her yeni satırda ya da temizlemede artar; eskimiş çeviriler gösterilmez.
    private var generation = 0

    private(set) var lastPair: (source: String, translation: String)?
    private(set) var lastError: TranslatorError?
    /// Süren çeviri. Okuma bunu beklemez; böylece çeviri sürerken gelen kısa satırlar da yakalanır.
    private(set) var translation: Task<Void, Never>?
    var onPair: ((String, String) -> Void)?
    /// Her çeviri denemesinden sonra çağrılır (başarılıysa nil).
    var onTranslationResult: ((TranslatorError?) -> Void)?

    init(reader: TextReader, translator: TextTranslator, server: SubtitleSending) {
        self.reader = reader
        self.translator = translator
        self.server = server
    }

    func process(_ frame: CGImage, region: CropRegion) async {
        // Yazı tanıma uzun sürebilir; arayüz takılmasın diye ana iş parçacığının dışında yapılır.
        let reader = self.reader
        let text = await Task.detached(priority: .userInitiated) {
            (try? reader.read(RegionCropper.crop(frame, to: region))) ?? ""
        }.value
        switch stabilizer.feed(text) {
        case .none:
            break
        case .clear:
            generation += 1
            server.clear()
        case .translate(let source):
            generation += 1
            let current = generation
            translation = Task { [weak self] in await self?.translate(source, generation: current) }
        }
    }

    private func translate(_ source: String, generation current: Int) async {
        do {
            let translated = try await translator.translate(source)
            guard current == generation else { return }
            lastError = nil
            onTranslationResult?(nil)
            guard stabilizer.shouldSend(source: source, translation: translated) else { return }
            server.sendSubtitle(translated, durationMs: 15000)
            lastPair = (source, translated)
            onPair?(source, translated)
        } catch {
            guard current == generation else { return }
            // Dil paketi eksikse ya da geçici bir hata olduysa satır ekranda kaldıkça yeniden denenir.
            lastError = error as? TranslatorError
            onTranslationResult?(lastError)
            stabilizer.forgetSent()
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
        generation += 1
        if stabilizer.reset() == .clear { server.clear() }
    }
}
