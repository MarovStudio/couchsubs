// SPDX-License-Identifier: AGPL-3.0-only

import Foundation
import Translation

protocol TextTranslator {
    func translate(_ text: String) async throws -> String
}

enum TranslatorError: Error, Equatable {
    case needsDownload
    case unsupported
}

enum TranslatorStatus: Equatable {
    case ready, needsDownload, unsupported
}

/// Apple'ın cihaz üstü çevirisi. Dil paketi yüklü olmalı; değilse `needsDownload` atar.
final class Translator: TextTranslator {
    private let source: Locale.Language
    private let target: Locale.Language
    private var session: TranslationSession?
    private var cache: [String: String] = [:]

    init(source: String = "en", target: String = "tr") {
        self.source = Locale.Language(identifier: source)
        self.target = Locale.Language(identifier: target)
    }

    static func status(source: String, target: String) async -> TranslatorStatus {
        switch await LanguageAvailability().status(from: Locale.Language(identifier: source), to: Locale.Language(identifier: target)) {
        case .installed: .ready
        case .supported: .needsDownload
        default: .unsupported
        }
    }

    func translate(_ text: String) async throws -> String {
        if let cached = cache[text] { return cached }
        if session == nil {
            switch await LanguageAvailability().status(from: source, to: target) {
            case .installed: session = TranslationSession(installedSource: source, target: target)
            case .supported: throw TranslatorError.needsDownload
            default: throw TranslatorError.unsupported
            }
        }
        let result = try await session!.translate(text).targetText
        cache[text] = result
        return result
    }
}
