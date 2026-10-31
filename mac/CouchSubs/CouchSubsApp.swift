// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

@main
struct CouchSubsApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .frame(minWidth: 560, idealWidth: 600, minHeight: 600, idealHeight: 660)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About CouchSubs") { model.showAbout = true }
            }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            if model.step == .done { MainView() } else { OnboardingView() }
        }
        .sheet(isPresented: $model.showAbout) { AboutView() }
    }
}
