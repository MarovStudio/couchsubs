// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

// Ortak bileşenler. Ölçü ve renkler Theme'den (design/tokens.json) gelir; ekranlar sabit değer kullanmaz.
// Bileşenlerin tarifi docs/TASARIM.md'de; Windows sürümü aynı bileşenleri aynı adlarla kurar.

/// Uygulamanın logosu (kanepe + altyazı).
struct LogoView: View {
    var size: CGFloat = 40

    var body: some View {
        // Simge dosyası macOS ızgarasına göre kenar boşluğu içerir (1024'te 824'lük kare); uygulama içinde kırpılır.
        Image("Logo")
            .resizable()
            .interpolation(.high)
            .frame(width: size * 1024 / 824, height: size * 1024 / 824)
            .frame(width: size, height: size)
            .clipped()
            .accessibilityHidden(true)
    }
}

/// Düğme türleri: birincil (sarı), ikincil (çerçeveli), tehlikeli (kırmızı).
struct CSButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger }
    var kind: Kind = .secondary
    var fullWidth = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.csButton)
            .foregroundStyle(foreground)
            .padding(.horizontal, Theme.space("xl"))
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: Theme.size("buttonHeight"))
            .background(background, in: RoundedRectangle(cornerRadius: Theme.radius("control")))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: Theme.radius("control")).strokeBorder(Color.csBorder)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: Theme.radius("control")))
    }

    private var foreground: Color {
        switch kind {
        case .primary: .csOnAccent
        case .secondary: .csText
        case .danger: .csOnDanger
        }
    }

    private var background: Color {
        switch kind {
        case .primary: .csAccent
        case .secondary: .csSurface
        case .danger: .csDanger
        }
    }
}

extension ButtonStyle where Self == CSButtonStyle {
    static var primary: CSButtonStyle { CSButtonStyle(kind: .primary) }
    static var secondary: CSButtonStyle { CSButtonStyle(kind: .secondary) }
    static var danger: CSButtonStyle { CSButtonStyle(kind: .danger) }
}

/// Başlıklı ya da başlıksız içerik kartı.
struct Card<Content: View>: View {
    var title: LocalizedStringKey?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space("m")) {
            if let title {
                Text(title).font(.csHeadline)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.space("xl"))
        .background(Color.csSurface, in: RoundedRectangle(cornerRadius: Theme.radius("card")))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius("card")).strokeBorder(Color.csBorder))
    }
}

/// Yumuşak sarı zeminde simge.
struct IconBadge: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: Theme.size("iconBadge") * 0.46, weight: .semibold))
            .foregroundStyle(Color.csAccentText)
            .frame(width: Theme.size("iconBadge"), height: Theme.size("iconBadge"))
            .background(Color.csAccentSoft, in: RoundedRectangle(cornerRadius: Theme.radius("control")))
            .accessibilityHidden(true)
    }
}

/// Sihirbaz adımlarının ortak düzeni: simge, başlık, açıklama, içerik.
struct StepLayout<Content: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space("l")) {
            IconBadge(symbol: symbol)
            Text(title)
                .font(.csDisplay)
                .padding(.top, Theme.space("xs"))
            Text(message)
                .font(.csBody)
                .foregroundStyle(Color.csSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            content
                .padding(.top, Theme.space("s"))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Numaralı talimat satırı.
struct NumberedRow: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.space("m")) {
            Text("\(number)")
                .font(.csCallout.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.csAccentText)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.csAccentSoft))
            Text(text)
                .font(.csBody)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Renkli durum noktası, adı ve değeri.
struct StatusRow: View {
    let title: LocalizedStringKey
    let value: String
    let isGood: Bool

    var body: some View {
        HStack(spacing: Theme.space("m")) {
            Circle()
                .fill(isGood ? Color.csSuccess : Color.csWarning)
                .frame(width: Theme.size("statusDot"), height: Theme.size("statusDot"))
            Text(title).font(.csBody.weight(.semibold))
            Spacer()
            Text(value)
                .font(.csBody)
                .foregroundStyle(isGood ? Color.csText : Color.csSecondary)
                .lineLimit(1)
        }
    }
}

/// Tamamlanan bir adımın onayı.
struct DoneLabel: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.csBody.weight(.semibold))
            .foregroundStyle(Color.csSuccess)
    }
}

/// İkincil açıklama metni.
struct HintText: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.csCallout)
            .foregroundStyle(Color.csSecondary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Bir işlem başarısız olunca gösterilen hata metni.
struct ErrorText: View {
    let error: String?

    var body: some View {
        if let error {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.csCallout)
                .foregroundStyle(Color.csWarning)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Uygulamanın tamamına zemin rengi, yazı rengi ve temel yazı boyutunu verir.
struct AppSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.csBody)
            .foregroundStyle(Color.csText)
            .tint(Color.csAccentText)
            .background(Color.csBackground)
    }
}

extension View {
    func appSurface() -> some View { modifier(AppSurface()) }
}
