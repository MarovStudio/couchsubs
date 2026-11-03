// SPDX-License-Identifier: AGPL-3.0-only

import CouchSubsCore
import SwiftUI

/// TV uygulamasını geliştirici moduyla kurma adımları. Yapılacak bir şey yoksa görünmez.
struct TVAppCard: View {
    @Environment(AppModel.self) private var model
    @State private var passphrase = ""

    var body: some View {
        Group {
            switch model.tvApp {
            case .unknown:
                EmptyView()
            case .working:
                Card(title: "CouchSubs TV app") {
                    HStack(spacing: Theme.space("s")) {
                        ProgressView().controlSize(.small)
                        Text("Checking the TV app…").foregroundStyle(Color.csSecondary)
                    }
                }
            case .upToDate(let version):
                Card(title: "CouchSubs TV app") {
                    DoneLabel(text: String(format: String(localized: "The TV app is ready (version %@)."), version))
                }
            case .devModeOff:
                Card(title: "CouchSubs TV app") {
                    Text("The TV app is not installed. CouchSubs can install it once Developer Mode is on.")
                    HintText(text: "1. Create a free account at webostv.developer.lge.com.")
                    HintText(text: "2. On the TV, install Developer Mode from the LG Content Store and sign in.")
                    HintText(text: "3. Turn on Dev Mode Status. The TV restarts and this screen continues by itself.")
                }
                // Kullanıcı TV'de geliştirici modunu açınca kendiliğinden devam eder.
                .task {
                    while !Task.isCancelled, model.tvApp == .devModeOff {
                        try? await Task.sleep(for: .seconds(3))
                        await model.refreshTVApp()
                    }
                }
            case .needsPassphrase(let error):
                passphraseCard(error: error)
            case .failed(let error):
                Card(title: "CouchSubs TV app") {
                    ErrorText(error: Self.message(for: error))
                    Button("Try again") { Task { await model.refreshTVApp() } }.buttonStyle(.secondary)
                }
            }
        }
    }

    private func passphraseCard(error: DevModeError?) -> some View {
        Card(title: "CouchSubs TV app") {
            Text("Developer Mode is on. One last step to install the TV app:")
            HintText(text: "Open the Developer Mode app on the TV, turn on Key Server and keep the app on screen. Type the Passphrase it shows.")
            HStack {
                TextField("Passphrase", text: $passphrase)
                    .textFieldStyle(CSTextFieldStyle())
                Button("Install on the TV") { Task { await model.installTVApp(passphrase: passphrase) } }
                    .buttonStyle(.primary)
                    .disabled(passphrase.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ErrorText(error: error.map(Self.message))
        }
    }

    private static func message(for error: DevModeError) -> String {
        switch error {
        case .keyServerOff: String(localized: "Key Server is off. Turn it on in the Developer Mode app and keep the app on screen.")
        case .wrongPassphrase: String(localized: "The passphrase is not correct. Check it on the TV screen.")
        case .keyRefused: String(localized: "The TV refused the key. Open Key Server and type the passphrase again.")
        case .unreachable: String(localized: "The TV did not respond. Make sure it is on and on the same network.")
        case .installFailed: String(localized: "The TV app could not be installed. Check the TV's free space and try again.")
        }
    }
}
