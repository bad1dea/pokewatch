import SwiftUI

/// Connection, sprite packs, and every watch setting.
struct WatchScreen: View {
    @Environment(PhoneModel.self) private var model

    var body: some View {
        @Bindable var s = model.settings
        Form {
            SwiftUI.Section {
                LabeledContent("Apple Watch", value: connection)
                if model.sync.paired && !model.sync.watchAppInstalled {
                    Text("Install PokéWatch on the watch from the Watch app's Available Apps.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } footer: {
                Text("Settings sync both ways; the most recent change wins.")
            }

            SwiftUI.Section {
                ForEach(SpritePackKind.allCases) { pack in packRow(pack) }
            } header: {
                Text("Sprite packs")
            } footer: {
                Text("Apple caps watch apps at 75 MB, so these extras travel from the iPhone and are stored on the watch. Transfers continue in the background; keep the watch near the iPhone.")
            }

            SwiftUI.Section("Clock") {
                Toggle("24-hour time", isOn: $s.use24Hour)
                Toggle("Seconds", isOn: $s.showSeconds)
                Toggle("Analog second hand", isOn: $s.analogSeconds)
                Toggle("Date", isOn: $s.showDate)
            }
            SwiftUI.Section("On the face") {
                Toggle("Battery", isOn: $s.showBattery)
                Toggle("Activity", isOn: $s.showActivity)
            }
            SwiftUI.Section("Motion") {
                Picker("Animation", selection: $s.intensity) {
                    ForEach(AnimationIntensity.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Reduce motion", isOn: $s.reducedMotion)
                Toggle("Haptics", isOn: $s.haptics)
            }
            SwiftUI.Section {
                Toggle("Use Health data", isOn: $s.useHealth)
                Stepper(value: $s.stepGoal, in: SettingsStore.stepGoalRange, step: 500) {
                    LabeledContent("Step goal", value: s.stepGoal.formatted())
                }
                Toggle("Heart rate", isOn: $s.heartRate)
            } header: {
                Text("Activity")
            } footer: {
                Text("Health data is read on the watch only and never leaves it.")
            }
            SwiftUI.Section("Keep it on screen") {
                Text("On the watch: Settings › General › Return to Clock › After 1 hour, then PokéWatch › Return to App. For one-press access after that, set the Action button to a Shortcut that opens PokéWatch.")
                    .font(.footnote)
            }
            SwiftUI.Section("About") {
                LabeledContent("Pokémon", value: "\(model.registry.characters.count)")
                LabeledContent("Version", value: Bundle.main.shortVersion)
                Text("Sprites from the PokeAPI sprites project. Pokémon © Nintendo, Creatures, GAME FREAK. Unofficial, non-commercial.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Watch")
        .onAppear { model.packs.measure() }
    }

    private var connection: String {
        if !model.sync.activated { return "Connecting…" }
        if !model.sync.paired { return "Not paired" }
        if !model.sync.watchAppInstalled { return "App not installed" }
        return model.sync.reachable ? "Connected" : "Paired"
    }

    @ViewBuilder
    private func packRow(_ pack: SpritePackKind) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pack.title)
                Text(detail(pack)).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            switch model.state(of: pack) {
            case .installed:
                Label("On watch", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon).font(.footnote.weight(.semibold)).foregroundStyle(Palette.electric)
            case .sending(let p):
                ProgressView(value: p).frame(width: 70)
            case .building:
                ProgressView()
            case .ready:
                Button("Send") { model.send(pack) }.buttonStyle(.borderedProminent).foregroundStyle(.black)
            case .unavailable:
                Text("Watch needed").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func detail(_ pack: SpritePackKind) -> String {
        guard let bytes = model.packs.sizes[pack] else { return pack.detail }
        return "\(pack.detail) \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))."
    }
}

extension Bundle {
    var shortVersion: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
