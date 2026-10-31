// SPDX-License-Identifier: AGPL-3.0-only

import CoreGraphics
import Vision

protocol TextReader: Sendable {
    func read(_ image: CGImage) throws -> String
}

/// Apple Vision ile cihaz üstünde yazı tanıma. Satırlar yukarıdan aşağı birleştirilir.
struct VisionReader: TextReader {
    var language = "en"

    func read(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [language]
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? [])
            .compactMap { observation -> (CGFloat, String)? in
                guard let candidate = observation.topCandidates(1).first, candidate.confidence >= 0.5 else { return nil }
                return (observation.boundingBox.midY, candidate.string)
            }
            .sorted { $0.0 > $1.0 }
            .map(\.1)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
