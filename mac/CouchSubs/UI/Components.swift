// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

/// Sihirbaz adımlarının ortak düzeni: simge, başlık, açıklama, içerik.
struct StepLayout<Content: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.tint)
            Text(title)
                .font(.title.bold())
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            content
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
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.callout.monospacedDigit().bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(.tint.opacity(0.15)))
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Renkli durum noktası ve metni.
struct StatusRow: View {
    let title: LocalizedStringKey
    let value: String
    let isGood: Bool

    var body: some View {
        HStack {
            Circle().fill(isGood ? Color.green : Color.orange).frame(width: 9, height: 9)
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).lineLimit(1)
        }
    }
}

/// Bir işlem sürerken gösterilen hata metni.
struct ErrorText: View {
    let error: String?

    var body: some View {
        if let error {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.callout)
        }
    }
}
