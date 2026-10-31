// SPDX-License-Identifier: AGPL-3.0-only

import CouchSubsCore
import SwiftUI

struct TVStep: View {
    @Environment(AppModel.self) private var model
    @State private var tvs: [LGTV] = []
    @State private var searching = false
    @State private var working = false
    @State private var error: String?

    var body: some View {
        StepLayout(symbol: "tv.fill", title: "Connect your TV",
                   message: "Turn on the TV and open the CouchSubs TV app. When you press Connect, the TV asks for permission once — accept it with the remote.") {
            VStack(alignment: .leading, spacing: 12) {
                if let tv = model.tv {
                    Label(tv.name, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
                HStack {
                    Text("TV").font(.headline)
                    if searching { ProgressView().controlSize(.small) }
                    Spacer()
                    Button("Search again") { Task { await search() } }.disabled(searching)
                }
                if tvs.isEmpty && !searching {
                    Text("No LG TV found. Make sure the TV is on and on the same network.")
                        .foregroundStyle(.secondary).font(.callout)
                }
                ForEach(tvs, id: \.host) { tv in
                    HStack {
                        Text(verbatim: "\(tv.name) — \(tv.host)")
                        Spacer()
                        Button("Connect") { Task { await pair(tv) } }.disabled(working)
                    }
                }
                if working {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Accept the request on the TV…").foregroundStyle(.secondary)
                    }
                }
                ErrorText(error: error)
            }
        }
        .task { await search() }
    }

    private func search() async {
        searching = true
        tvs = await model.discoverTVs()
        searching = false
    }

    private func pair(_ tv: LGTV) async {
        working = true
        error = nil
        do { try await model.pair(tv) } catch { self.error = String(localized: "The TV did not respond. Is the CouchSubs TV app installed?") }
        working = false
    }
}
