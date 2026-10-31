// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

struct WelcomeStep: View {
    var body: some View {
        StepLayout(symbol: "captions.bubble.fill", title: "Welcome to CouchSubs",
                   message: "CouchSubs reads the English subtitles of your PS5 games and shows a Turkish translation on your TV, on top of the game. You keep playing on the TV with your own controller.") {
            VStack(alignment: .leading, spacing: 10) {
                Text("You will need:").font(.headline)
                Label("A PS5 on the same Wi-Fi network as this Mac", systemImage: "gamecontroller")
                Label("An LG TV with the CouchSubs TV app", systemImage: "tv")
                Label("A free second PlayStation Network account", systemImage: "person.2")
            }
            .padding(.top, 6)
        }
    }
}
