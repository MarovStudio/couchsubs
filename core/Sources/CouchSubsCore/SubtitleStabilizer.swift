// SPDX-License-Identifier: AGPL-3.0-only

import Foundation

/// Okuma hattının bir kareye vereceği tepki.
public enum StabilizerAction: Equatable {
    case none
    case translate(String)
    case clear
}

/// Kare kare gelen OCR çıktısını izler; altyazı kararlı hale gelince çevrilmesini,
/// ekrandan kalkınca TV'den temizlenmesini ister. Aynı altyazıyı tekrar göndermez.
public struct SubtitleStabilizer {
    private let similarity: Double
    private let stableFrames: Int
    private let emptyFramesToClear: Int

    private var candidate = ""
    private var candidateCount = 0
    private var sent = ""
    private var emptyCount = 0

    public init(similarity: Double = 0.85, stableFrames: Int = 2, emptyFramesToClear: Int = 2) {
        self.similarity = similarity
        self.stableFrames = stableFrames
        self.emptyFramesToClear = emptyFramesToClear
    }

    public mutating func feed(_ rawText: String) -> StabilizerAction {
        let text = TextMatch.normalize(rawText)
        // 3 karakterden kısa okumalar (gürültü, tek simge) boş kare sayılır.
        guard text.count >= 3 else {
            candidate = ""
            candidateCount = 0
            emptyCount += 1
            if emptyCount == emptyFramesToClear && !sent.isEmpty {
                sent = ""
                return .clear
            }
            return .none
        }

        emptyCount = 0
        if TextMatch.isSimilar(text, candidate, threshold: similarity) {
            candidateCount += 1
        } else {
            candidate = text
            candidateCount = 1
        }
        // Daktilo efektinde metin büyürken aday değişir; tamamlanıp kararlı olunca gider.
        guard candidateCount == stableFrames, !TextMatch.isSimilar(text, sent, threshold: similarity) else {
            return .none
        }
        sent = text
        return .translate(rawText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Çeviri kaynağıyla neredeyse aynıysa metin zaten hedef dildedir (ör. konsolun Türkçe menüleri).
    public mutating func shouldSend(source: String, translation: String) -> Bool {
        !TextMatch.isSimilar(TextMatch.normalize(source), TextMatch.normalize(translation), threshold: 0.90)
    }

    public mutating func reset() -> StabilizerAction {
        candidate = ""
        candidateCount = 0
        emptyCount = 0
        guard !sent.isEmpty else { return .none }
        sent = ""
        return .clear
    }
}
