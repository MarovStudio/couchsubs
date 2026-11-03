// SPDX-License-Identifier: AGPL-3.0-only

import CoreGraphics
import Foundation
import Vision

protocol TextReader: Sendable {
    func read(_ image: CGImage) throws -> String
    /// `deep` false ise boş bölgede büyütülmüş okuma denenmez (işlemciyi çok daha az yorar).
    func read(_ image: CGImage, deep: Bool) throws -> String
}

extension TextReader {
    func read(_ image: CGImage, deep: Bool) throws -> String { try read(image) }
}

/// Apple Vision ile cihaz üstünde yazı tanıma. Satırlar yukarıdan aşağı birleştirilir.
struct VisionReader: TextReader {
    var language = "en"

    func read(_ image: CGImage) throws -> String {
        try Self.firstReading(of: image, using: recognize)
    }

    func read(_ image: CGImage, deep: Bool) throws -> String {
        deep ? try read(image) : try recognize(image)
    }

    /// Vision geniş bölgede "Go!" gibi kısa satırları sık sık hiç bulmaz. Bölgede yazı çıkmazsa
    /// ortadaki şerit (altyazılar ortalıdır) ve bölgenin tamamı büyütülerek aynı anda yeniden okunur;
    /// ikisi de yazı bulursa şeridinki seçilir. Aynı anda okumak, boş karede yeni satırı geç fark etmeyi önler.
    static func firstReading(of image: CGImage, using recognize: @Sendable (CGImage) throws -> String) throws -> String {
        let text = try recognize(image)
        guard text.isEmpty else { return text }

        let fallbacks: [@Sendable () -> CGImage?] = [
            { centerStrip(of: image, widthFraction: 0.4).flatMap { scaled($0, by: 2) } },
            { scaled(image, by: 2) },
        ]
        let results = Results(count: fallbacks.count)
        DispatchQueue.concurrentPerform(iterations: fallbacks.count) { index in
            guard let variant = fallbacks[index]() else { return }
            results.set(index, Result { try recognize(variant) })
        }
        for result in results.all {
            if let text = try result?.get(), !text.isEmpty { return text }
        }
        return ""
    }

    /// Aynı anda yapılan okumaların sonuçları.
    private final class Results: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [Result<String, Error>?]
        init(count: Int) { values = Array(repeating: nil, count: count) }
        func set(_ index: Int, _ value: Result<String, Error>) { lock.withLock { values[index] = value } }
        var all: [Result<String, Error>?] { lock.withLock { values } }
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
