// SPDX-License-Identifier: AGPL-3.0-only

import RemotePlay
import SwiftUI

struct ConsoleStep: View {
    @Environment(AppModel.self) private var model
    @State private var consoles: [ConsoleInfo] = []
    @State private var selected: String?
    @State private var manualHost = ""
    @State private var pin = ""
    @State private var searching = false
    @State private var working = false
    @State private var error: String?

    private var host: String { selected ?? manualHost.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        StepLayout(symbol: "gamecontroller.fill", title: "Connect your PS5",
                   message: "Turn on the PS5. As the second user, open Settings › System › Remote Play › Pair Device and enter the 8-digit code shown there.") {
            VStack(alignment: .leading, spacing: 12) {
                if let console = model.console {
                    Label(console.name, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
                HStack {
                    Text("PS5").font(.headline)
                    if searching { ProgressView().controlSize(.small) }
                    Spacer()
                    Button("Search again") { Task { await search() } }.disabled(searching)
                }
                if consoles.isEmpty && !searching {
                    Text("No PS5 found. Make sure it is on and on the same network, or enter its IP address.")
                        .foregroundStyle(.secondary).font(.callout)
                    TextField("IP address, e.g. 192.168.1.20", text: $manualHost).textFieldStyle(.roundedBorder)
                } else {
                    Picker("PS5", selection: $selected) {
                        ForEach(consoles, id: \.host) { Text(verbatim: "\($0.name) — \($0.host)").tag(Optional($0.host)) }
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
                }
                TextField("8-digit code", text: $pin)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.monospacedDigit())
                    .frame(maxWidth: 200)
                HStack {
                    Button("Connect") { Task { await register() } }
                        .controlSize(.large)
                        .disabled(working || host.isEmpty || pin.filter(\.isNumber).count != 8)
                    if working { ProgressView().controlSize(.small) }
                }
                ErrorText(error: error)
            }
        }
        .task { await search() }
    }

    private func search() async {
        searching = true
        consoles = await model.discoverConsoles()
        if selected == nil { selected = consoles.first?.host }
        searching = false
    }

    private func register() async {
        working = true
        error = nil
        do { try await model.register(host: host, pin: pin) } catch { self.error = error.localizedDescription }
        working = false
    }
}
