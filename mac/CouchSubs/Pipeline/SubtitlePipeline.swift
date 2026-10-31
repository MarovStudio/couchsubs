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
    private var stabilizer = SubtitleStabilizer()

    private(set) var lastPair: (source: String, translation: String)?
    private(set) var lastError: TranslatorError?
    var onPair: ((String, String) -> Void)?

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
            server.clear()
        case .translate(let source):
            do {
                let translation = try await translator.translate(source)
                lastError = nil
                guard stabilizer.shouldSend(source: source, translation: translation) else { return }
                server.sendSubtitle(translation, durationMs: 15000)
                lastPair = (source, translation)
                onPair?(source, translation)
            } catch let error as TranslatorError {
                lastError = error
                stabilizer.forgetSent()
            } catch {
                // Geçici hata: satır ekranda kaldıkça yeniden denenir.
                lastError = nil
                stabilizer.forgetSent()
            }
        }
    }

    /// Okuma durunca TV'deki son altyazıyı kaldırır.
    func reset() {
        if stabilizer.reset() == .clear { server.clear() }
    }
}
