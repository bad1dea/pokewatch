import Foundation
import Observation
import SwiftUI

enum AccentChoice: String, CaseIterable, Codable, Identifiable, Sendable {
    case electric, ember, aqua, leaf, psychic, ghost, moonlight, snow
    var id: String { rawValue }

    var title: String {
        switch self {
        case .electric: "Electric"
        case .ember: "Ember"
        case .aqua: "Aqua"
        case .leaf: "Leaf"
        case .psychic: "Psychic"
        case .ghost: "Ghost"
        case .moonlight: "Moonlight"
        case .snow: "Snow"
        }
    }

    var hex: String {
        switch self {
        case .electric: "#FFE100"
        case .ember: "#FF8A3D"
        case .aqua: "#5CC8F0"
        case .leaf: "#7CD67A"
        case .psychic: "#FF9ACB"
        case .ghost: "#A77BE8"
        case .moonlight: "#FFD34A"
        case .snow: "#F2F2F2"
        }
    }

    var color: Color { Color(hex: hex) }
}

enum AODAppearance: String, CaseIterable, Codable, Identifiable, Sendable {
    case sleeping, silhouette, clockOnly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sleeping: "Sleeping Pokémon"
        case .silhouette: "Silhouette"
        case .clockOnly: "Clock only"
        }
    }
}

enum RetroPalette: String, CaseIterable, Codable, Identifiable, Sendable {
    case classicGreen, monochrome, pikaYellow
    var id: String { rawValue }
    var title: String {
        switch self {
        case .classicGreen: "Classic green"
        case .monochrome: "Monochrome"
        case .pikaYellow: "Yellow"
        }
    }
    /// Lightest → darkest.
    var shades: [RGB] {
        switch self {
        case .classicGreen: ["#C4CF6A", "#8BA34A", "#4E7A3A", "#26432A"].compactMap(RGB.init(hex:))
        case .monochrome: ["#E8E8E8", "#A8A8A8", "#686868", "#363636"].compactMap(RGB.init(hex:))
        case .pikaYellow: ["#FFE36B", "#E0A92A", "#A8662A", "#5E3416"].compactMap(RGB.init(hex:))
        }
    }
}

/// User preferences, persisted locally in the app's own UserDefaults.
@MainActor @Observable
final class SettingsStore {
    @ObservationIgnored private let defaults: UserDefaults

    var characterID: String { didSet { save(characterID, .characterID) } }
    var faceStyle: FaceStyle { didSet { save(faceStyle.rawValue, .faceStyle) } }
    var accent: AccentChoice { didSet { save(accent.rawValue, .accent) } }
    var use24Hour: Bool { didSet { save(use24Hour, .use24Hour) } }
    var showSeconds: Bool { didSet { save(showSeconds, .showSeconds) } }
    var showDate: Bool { didSet { save(showDate, .showDate) } }
    var showBattery: Bool { didSet { save(showBattery, .showBattery) } }
    var showActivity: Bool { didSet { save(showActivity, .showActivity) } }
    var intensity: AnimationIntensity { didSet { save(intensity.rawValue, .intensity) } }
    var aodAppearance: AODAppearance { didSet { save(aodAppearance.rawValue, .aodAppearance) } }
    var haptics: Bool { didSet { save(haptics, .haptics) } }
    var reducedMotion: Bool { didSet { save(reducedMotion, .reducedMotion) } }
    var stepGoal: Int { didSet { save(stepGoal, .stepGoal) } }
    var retroPalette: RetroPalette { didSet { save(retroPalette.rawValue, .retroPalette) } }
    var analogSeconds: Bool { didSet { save(analogSeconds, .analogSeconds) } }
    var useHealth: Bool { didSet { save(useHealth, .useHealth) } }
    var heartRate: Bool { didSet { save(heartRate, .heartRate) } }
    var variant: AnimationVariant { didSet { save(variant.rawValue, .variant) } }

    enum Key: String, CaseIterable {
        case characterID, faceStyle, accent, use24Hour, showSeconds, showDate, showBattery, showActivity,
             intensity, aodAppearance, haptics, reducedMotion, stepGoal, retroPalette, analogSeconds,
             useHealth, heartRate, variant
        var name: String { "settings.\(rawValue)" }
    }

    static let stepGoalRange = 1000...30000

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func string(_ k: Key) -> String? { defaults.string(forKey: k.name) }
        func bool(_ k: Key, _ d: Bool) -> Bool { defaults.object(forKey: k.name) as? Bool ?? d }

        characterID = string(.characterID) ?? "pikachu"
        faceStyle = string(.faceStyle).flatMap(FaceStyle.init(rawValue:)) ?? .electric
        accent = string(.accent).flatMap(AccentChoice.init(rawValue:)) ?? .electric
        use24Hour = bool(.use24Hour, ClockFormatter.localePrefers24h)
        showSeconds = bool(.showSeconds, true)
        showDate = bool(.showDate, true)
        showBattery = bool(.showBattery, true)
        showActivity = bool(.showActivity, true)
        intensity = string(.intensity).flatMap(AnimationIntensity.init(rawValue:)) ?? .balanced
        aodAppearance = string(.aodAppearance).flatMap(AODAppearance.init(rawValue:)) ?? .sleeping
        haptics = bool(.haptics, true)
        reducedMotion = bool(.reducedMotion, false)
        let goal = defaults.object(forKey: Key.stepGoal.name) as? Int ?? 8000
        stepGoal = min(max(goal, Self.stepGoalRange.lowerBound), Self.stepGoalRange.upperBound)
        retroPalette = string(.retroPalette).flatMap(RetroPalette.init(rawValue:)) ?? .classicGreen
        analogSeconds = bool(.analogSeconds, true)
        useHealth = bool(.useHealth, true)
        heartRate = bool(.heartRate, false)
        variant = string(.variant).flatMap(AnimationVariant.init(rawValue:)) ?? .idle
    }

    /// False while launch-argument overrides are applied, so automation never
    /// overwrites the user's saved choices.
    @ObservationIgnored private var persisting = true

    private func save(_ value: Any, _ key: Key) {
        guard persisting else { return }
        defaults.set(value, forKey: key.name)
    }

    /// Applies `--face`, `--pokemon`, `--accent`, `--palette` launch arguments
    /// (used by the screenshot script) without persisting them.
    func applyLaunchOverrides(_ args: LaunchOptions) {
        persisting = false
        defer { persisting = true }
        if let f = args.face { faceStyle = f }
        if let p = args.pokemon { characterID = p }
        if let a = args.accent { accent = a }
        if let r = args.palette { retroPalette = r }
    }

    func resetToDefaults() {
        for k in Key.allCases { defaults.removeObject(forKey: k.name) }
        let fresh = SettingsStore(defaults: defaults)
        characterID = fresh.characterID; faceStyle = fresh.faceStyle; accent = fresh.accent
        use24Hour = fresh.use24Hour; showSeconds = fresh.showSeconds; showDate = fresh.showDate
        showBattery = fresh.showBattery; showActivity = fresh.showActivity; intensity = fresh.intensity
        aodAppearance = fresh.aodAppearance; haptics = fresh.haptics; reducedMotion = fresh.reducedMotion
        stepGoal = fresh.stepGoal; retroPalette = fresh.retroPalette; analogSeconds = fresh.analogSeconds
        useHealth = fresh.useHealth; heartRate = fresh.heartRate; variant = fresh.variant
    }
}
