// SPDX-License-Identifier: AGPL-3.0-only

import Foundation

/// Yazının yeri, içinde bulunduğu alanın kenarlarına oranla (0–1, üstten ve soldan).
public struct TextBox: Equatable, Sendable {
    public var left: Double
    public var top: Double
    public var right: Double
    public var bottom: Double

    public init(left: Double, top: Double, right: Double, bottom: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    public func union(_ other: TextBox) -> TextBox {
        TextBox(left: min(left, other.left), top: min(top, other.top), right: max(right, other.right), bottom: max(bottom, other.bottom))
    }

    /// Bu kutu `area` içindeki oranlarsa, aynı yerin `area`'yı içeren çerçevedeki oranları.
    public func placed(in area: TextBox) -> TextBox {
        let width = area.right - area.left, height = area.bottom - area.top
        return TextBox(left: area.left + left * width, top: area.top + top * height,
                       right: area.left + right * width, bottom: area.top + bottom * height)
    }
}

/// Yazı tanımanın bulduğu bir satır.
public struct TextLine: Equatable, Sendable {
    public var text: String
    /// Okunan alana göre yeri; bilinmiyorsa nil.
    public var box: TextBox?

    public init(_ text: String, box: TextBox? = nil) {
        self.text = text
        self.box = box
    }
}

/// Bir karenin okunan satırları, yukarıdan aşağı.
public struct Reading: Equatable, Sendable {
    public var lines: [TextLine]

    public init(lines: [TextLine]) {
        self.lines = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    public static let empty = Reading(lines: [])

    /// Satırları ayrı ayrı bilinmeyen eski okuyucular için: her satır sonu bir satırdır.
    public init(text: String) {
        self.init(lines: text.components(separatedBy: .newlines).map { TextLine($0.trimmingCharacters(in: .whitespaces)) })
    }

    public var text: String { lines.map(\.text).joined(separator: "\n") }

    /// Bütün satırları içine alan kutu; hiçbir satırın yeri bilinmiyorsa nil.
    public var box: TextBox? {
        lines.compactMap(\.box).reduce(nil) { total, box in total?.union(box) ?? box }
    }

    /// Oyunun düğme ipuçları ("R2 Swing", "△ Pick up") çıkarılmış hali; bunlar altyazı değildir.
    public func withoutButtonPrompts() -> Reading {
        Reading(lines: lines.filter { !ButtonPrompts.isPrompt($0.text) })
    }

    /// Satır kutularını `area` içindeki oranlardan dış çerçevenin oranlarına taşır.
    public func placed(in area: TextBox) -> Reading {
        Reading(lines: lines.map { TextLine($0.text, box: $0.box?.placed(in: area)) })
    }
}

/// Oyunların ekranda gösterdiği kumanda ipuçlarını tanır: "R2 Swing", "L1 + R1 Spartan Rage",
/// "△ Pick up", "Press ✕ to jump". Konuşma satırları dokunulmadan kalır.
public enum ButtonPrompts {
    /// Her zaman kumanda düğmesi olan simgeler ve adlar (yazı tanıma bazen köşeli parantezle okur).
    private static let buttons: Set<String> = [
        "R1", "R2", "R3", "L1", "L2", "L3", "OPTIONS", "TOUCHPAD",
        "✕", "×", "⨯", "✖", "○", "◯", "●", "□", "▢", "◻", "■", "△", "▲", "⨂",
    ]
    /// Simge yazı tanımada harfe dönüşebilir; yalnız ipucu kalıbında düğme sayılır.
    private static let lookalikes: Set<String> = ["X", "O"]
    private static let verbs: Set<String> = ["press", "hold", "tap", "push", "use", "mash", "release"]
    private static let brackets = CharacterSet(charactersIn: "()[]{}<>「」")

    public static func isPrompt(_ line: String) -> Bool {
        let tokens = line
            .components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "+/")))
            .map { $0.trimmingCharacters(in: brackets) }
            .filter { !$0.isEmpty }
        guard let first = tokens.first else { return false }

        let isButton = { (token: String) in buttons.contains(token.uppercased()) }
        let words = tokens.filter { !isButton($0) && $0.contains(where: \.isLetter) }

        // "R2 Swing", "△ Pick up", "L1 R1 Spartan Rage"
        if isButton(first) { return words.count <= 5 }
        // "X Interact", "O Back": ardından kısa, büyük harfle başlayan, noktalamasız bir eylem gelir.
        if lookalikes.contains(first), tokens.count >= 2, tokens.count <= 4,
           tokens[1].first?.isUppercase == true, !SubtitleStabilizer.endsSentence(line) {
            return true
        }
        // "Press ✕ to jump", "Hold R2 to aim"
        if verbs.contains(first.lowercased()), tokens.count >= 2, tokens.count <= 10 {
            let second = tokens[1]
            return isButton(second) || lookalikes.contains(second)
        }
        return false
    }
}
