// SPDX-License-Identifier: AGPL-3.0-only

import CouchSubsCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.csTitle)
                Spacer()
            }
            .padding(.horizontal, Theme.space("xxl"))
            .padding(.top, Theme.space("xl"))
            .padding(.bottom, Theme.space("m"))

            ScrollView {
                VStack(spacing: Theme.space("l")) {
                    Card(title: "On the TV") {
                        Picker("Text size", selection: $model.settings.style.fontSize) {
                            Text("Small").tag(36)
                            Text("Medium").tag(46)
                            Text("Large").tag(58)
                        }
                        .pickerStyle(.segmented)
                        // Sürüklerken TV'de örnek altyazı görünür; böylece yeri doğrudan ekranda ayarlanır.
                        Slider(value: Binding(get: { Double(model.settings.style.bottomPercent) },
                                              set: { model.settings.style.bottomPercent = Int($0.rounded()) }), in: 0...85) {
                            Text("Position on screen")
                        } minimumValueLabel: {
                            Text("Bottom").font(.csCallout).foregroundStyle(Color.csSecondary)
                        } maximumValueLabel: {
                            Text("Top").font(.csCallout).foregroundStyle(Color.csSecondary)
                        } onEditingChanged: { editing in
                            if editing { model.sendTestSubtitle() }
                        }
                        HintText(text: "You can also move subtitles with the ▲ and ▼ buttons on the TV remote.")
                        Button("Send test subtitle") { model.sendTestSubtitle() }.buttonStyle(.secondary)
                    }
                    Card(title: "Language") {
                        Picker("Game language", selection: $model.settings.sourceLanguage) {
                            Text("English").tag("en")
                            Text("Japanese").tag("ja")
                            Text("German").tag("de")
                            Text("French").tag("fr")
                            Text("Spanish").tag("es")
                        }
                    }
                    Card(title: "Subtitle area") {
                        RegionPicker(region: $model.settings.region, frame: model.lastFrame)
                        HintText(text: "Adjust the frame so it covers where the game shows its subtitles.")
                    }
                    TVAppCard()
                    Card {
                        HStack(spacing: Theme.space("m")) {
                            Button("About CouchSubs") { model.showAbout = true }.buttonStyle(.secondary)
                            Spacer()
                            Button("Set up again…") { confirmReset = true }.buttonStyle(.secondary).foregroundStyle(Color.csDanger)
                        }
                    }
                }
                .padding(.horizontal, Theme.space("xxl"))
                .padding(.bottom, Theme.space("xl"))
            }

            Divider().overlay(Color.csBorder)
            HStack {
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.primary).keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, Theme.space("xxl"))
            .padding(.vertical, Theme.space("l"))
            .background(Color.csSurface)
        }
        .frame(width: 600, height: 720)
        .background(Color.csBackground)
        .confirmationDialog("Set up again?", isPresented: $confirmReset) {
            Button("Set up again", role: .destructive) {
                model.resetSetup()
                dismiss()
            }
        } message: {
            Text("The saved PS5, account and TV connection will be removed.")
        }
    }
}

/// Son karenin üstünde altyazı bölgesini gösteren ve kenarlardan ayarlanan çerçeve.
struct RegionPicker: View {
    @Binding var region: CropRegion
    let frame: CGImage?

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                let size = geometry.size
                ZStack(alignment: .topLeading) {
                    if let frame {
                        Image(decorative: frame, scale: 1).resizable()
                    } else {
                        RoundedRectangle(cornerRadius: 6).fill(Color.csBackground)
                        Text("The game picture appears here once translating starts.")
                            .font(.csCaption).foregroundStyle(Color.csSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    Rectangle()
                        .strokeBorder(Color.csAccent, lineWidth: 2)
                        .background(Color.csAccent.opacity(0.14))
                        .frame(width: size.width * (region.right - region.left), height: size.height * (region.bottom - region.top))
                        .offset(x: size.width * region.left, y: size.height * region.top)
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius("control")))

            Grid(alignment: .leading) {
                GridRow {
                    Text("Top")
                    Slider(value: $region.top, in: 0...max(0, region.bottom - 0.05))
                }
                GridRow {
                    Text("Bottom")
                    Slider(value: $region.bottom, in: min(1, region.top + 0.05)...1)
                }
                GridRow {
                    Text("Left")
                    Slider(value: $region.left, in: 0...max(0, region.right - 0.05))
                }
                GridRow {
                    Text("Right")
                    Slider(value: $region.right, in: min(1, region.left + 0.05)...1)
                }
            }
            Button("Reset area") { region = CropRegion() }.buttonStyle(.secondary)
        }
    }
}
