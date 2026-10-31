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
        try Self.firstReading(of: image, using: recognize)
    }

    /// Vision geniş bölgede "Go!" gibi kısa satırları sık sık hiç bulmaz. Bölgede yazı çıkmazsa
    /// önce ortadaki şerit (altyazılar ortalıdır), sonra bölgenin tamamı büyütülerek yeniden okunur.
    static func firstReading(of image: CGImage, using recognize: (CGImage) throws -> String) rethrows -> String {
        let candidates: [() -> CGImage?] = [
            { image },
            { centerStrip(of: image, widthFraction: 0.4).flatMap { scaled($0, by: 2) } },
            { scaled(image, by: 2) },
        ]
        for candidate in candidates {
            guard let variant = candidate() else { continue }
            let text = try recognize(variant)
            if !text.isEmpty { return text }
        }
        return ""
    }

    private func recognize(_ image: CGImage) throws -> String {
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

    private static func centerStrip(of image: CGImage, widthFraction: Double) -> CGImage? {
        let width = Double(image.width) * widthFraction
        return image.cropping(to: CGRect(x: (Double(image.width) - width) / 2, y: 0, width: width, height: Double(image.height)).integral)
    }

    private static func scaled(_ image: CGImage, by factor: Int) -> CGImage? {
        let width = image.width * factor, height = image.height * factor
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
