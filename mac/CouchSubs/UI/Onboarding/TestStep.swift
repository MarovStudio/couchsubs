// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

struct TestStep: View {
    @Environment(AppModel.self) private var model
    @State private var sent = false

    var body: some View {
        StepLayout(symbol: "checkmark.seal.fill", title: "Let's test it",
                   message: "CouchSubs will send a sample subtitle to your TV. It should appear at the bottom of the screen, on top of the game.") {
            VStack(alignment: .leading, spacing: 14) {
                Button("Send test subtitle") {
                    model.sendTestSubtitle()
                    sent = true
                }
                .controlSize(.large)
                if sent {
                    Text("Do you see it on the TV?").font(.headline)
                    HStack {
                        Button("Yes, I see it") { model.advance() }
                            .keyboardShortcut(.defaultAction)
                            .controlSize(.large)
                        Button("No") { model.step = .tv }
                            .controlSize(.large)
                    }
                    Text("If you don't see it, make sure the CouchSubs TV app is open and connect the TV again.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }
}
