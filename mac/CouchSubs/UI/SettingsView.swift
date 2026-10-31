// SPDX-License-Identifier: AGPL-3.0-only

import CouchSubsCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("Subtitle area") {
                    RegionPicker(region: $model.settings.region, frame: model.lastFrame)
                    Text("Adjust the frame so it covers where the game shows its subtitles.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Section("On the TV") {
                    Picker("Text size", selection: $model.settings.style.fontSize) {
                        Text("Small").tag(36)
                        Text("Medium").tag(46)
                        Text("Large").tag(58)
                    }
                    .pickerStyle(.segmented)
                    Slider(value: Binding(get: { Double(model.settings.style.bottomPercent) },
                                          set: { model.settings.style.bottomPercent = Int($0) }), in: 2...40) {
                        Text("Distance from bottom")
                    }
                    Button("Send test subtitle") { model.sendTestSubtitle() }
                }
                Section("Language") {
                    Picker("Game language", selection: $model.settings.sourceLanguage) {
                        Text("English").tag("en")
                        Text("Japanese").tag("ja")
                        Text("German").tag("de")
                        Text("French").tag("fr")
                        Text("Spanish").tag("es")
                    }
                }
                Section {
                    Button("Set up again…", role: .destructive) { confirmReset = true }
                    Button("About CouchSubs") { model.showAbout = true }
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 520, height: 640)
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
                        RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                        Text("The game picture appears here once translating starts.")
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    Rectangle()
                        .strokeBorder(.yellow, lineWidth: 2)
                        .background(Color.yellow.opacity(0.12))
                        .frame(width: size.width * (region.right - region.left), height: size.height * (region.bottom - region.top))
                        .offset(x: size.width * region.left, y: size.height * region.top)
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))

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
            Button("Reset area") { region = CropRegion() }
        }
    }
}
