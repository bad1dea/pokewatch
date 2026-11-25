import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var s = model.settings
        NavigationStack {
            List {
                Section("Look") {
                    Picker("Sprites", selection: $s.spriteStyle) {
                        ForEach(SpriteStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .onChange(of: s.spriteStyle) { _, _ in model.styleChanged() }
                    if SpriteLibrary.shared.hasShinyArt {
                        Toggle("Shiny", isOn: $s.shiny)
                    }
                    Picker("Accent", selection: $s.accent) {
                        ForEach(AccentChoice.allCases) { a in
                            HStack {
                                Circle().fill(a.color).frame(width: 10, height: 10)
                                Text(a.title)
                            }
                            .tag(a)
                        }
                    }
                    Picker("Retro palette", selection: $s.retroPalette) {
                        ForEach(RetroPalette.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Always On", selection: $s.aodAppearance) {
                        ForEach(AODAppearance.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section("Clock") {
                    Toggle("24-hour time", isOn: $s.use24Hour)
                    Toggle("Seconds", isOn: $s.showSeconds)
                    Toggle("Analog second hand", isOn: $s.analogSeconds)
                    Toggle("Date", isOn: $s.showDate)
                }

                Section("On the face") {
                    Toggle("Battery", isOn: $s.showBattery)
                    Toggle("Activity", isOn: $s.showActivity)
                }

                Section("Motion") {
                    Picker("Animation", selection: $s.intensity) {
                        ForEach(AnimationIntensity.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Reduce motion", isOn: $s.reducedMotion)
                    Toggle("Haptics", isOn: $s.haptics)
                }

                Section {
                    Toggle("Use Health data", isOn: $s.useHealth)
                        .onChange(of: s.useHealth) { _, on in
                            if on { Task { await model.health.requestAuthorization(includeHeartRate: s.heartRate) } }
                        }
                    Stepper(value: $s.stepGoal, in: SettingsStore.stepGoalRange, step: 500) {
                        VStack(alignment: .leading) {
                            Text("Step goal")
                            Text(s.stepGoal.formatted()).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                    Toggle("Heart rate", isOn: $s.heartRate)
                        .onChange(of: s.heartRate) { _, on in
                            if on { Task { await model.health.requestAuthorization(includeHeartRate: true) } }
                        }
                } header: {
                    Text("Activity")
                } footer: {
                    Text(model.health.isAvailable
                         ? "Read-only. Data stays on this watch. If access is denied the face simply hides activity."
                         : "Health data is not available on this device.")
                }

                Section {
                    Text("To come back to PokéWatch when you raise your wrist: Settings › General › Return to Clock › PokéWatch › Return to App.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Keep it on screen")
                }

                Section("About") {
                    LabeledContent("Pokémon", value: "\(model.registry.characters.count)")
                    LabeledContent("Version", value: Bundle.main.shortVersion)
                    Button("Reset settings", role: .destructive) { model.settings.resetToDefaults() }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

extension Bundle {
    var shortVersion: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
