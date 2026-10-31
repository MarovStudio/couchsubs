// SPDX-License-Identifier: AGPL-3.0-only

import RemotePlay
import SwiftUI

struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false

    private var ps5Status: (String, Bool) {
        (AppModel.statusText(model.sessionState, running: model.isRunning), model.sessionState == .streaming)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("CouchSubs").font(.largeTitle.bold())
                Spacer()
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .help(Text("Settings"))
            }

            Button {
                Task { model.isRunning ? model.stop() : await model.start() }
            } label: {
                Label(model.isRunning ? "Stop translating" : "Start translating",
                      systemImage: model.isRunning ? "stop.fill" : "play.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isRunning ? .red : .accentColor)
            .controlSize(.large)
            .disabled(model.isStarting)

            GroupBox {
                VStack(spacing: 10) {
                    StatusRow(title: "PS5", value: ps5Status.0, isGood: ps5Status.1)
                    StatusRow(title: "TV", value: model.tvClients > 0 ? String(localized: "Connected") : String(localized: "Waiting for the TV app"),
                              isGood: model.tvClients > 0)
                }
                .padding(6)
            }

            if model.translatorStatus == .needsDownload {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("The English–Turkish language pack is not downloaded yet.", systemImage: "arrow.down.circle")
                        Text("Open System Settings › General › Language & Region › Translation Languages and download English and Turkish.")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Open Language & Region") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension")!)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                }
            }

            GroupBox("Last subtitle") {
                VStack(alignment: .leading, spacing: 8) {
                    if model.lastTranslation.isEmpty {
                        Text("Subtitles will appear here while you play.").foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: model.lastSource).foregroundStyle(.secondary)
                        Text(verbatim: model.lastTranslation).font(.title3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }
            Spacer()
        }
        .padding(28)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
}
