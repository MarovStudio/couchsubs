// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "captions.bubble.fill").font(.system(size: 44)).foregroundStyle(.tint)
            Text("CouchSubs").font(.title.bold())
            Text(verbatim: AppIdentity.version).foregroundStyle(.secondary)
            Text("Free and open source under the GNU AGPL-3.0 license.")
                .multilineTextAlignment(.center)
            Text("Remote Play connection by chiaki-ng (AGPL-3.0). Thanks to its developers.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Link("Source code", destination: AppIdentity.sourceURL)
            Link("chiaki-ng", destination: URL(string: "https://github.com/chiaki-ng/chiaki-ng")!)
            Text("CouchSubs is not affiliated with Sony Interactive Entertainment. PlayStation and PS5 are trademarks of Sony Interactive Entertainment Inc.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }.keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(width: 420)
    }
}
