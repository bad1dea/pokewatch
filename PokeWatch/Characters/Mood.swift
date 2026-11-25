import Foundation

enum Mood: String, Codable, CaseIterable, Sendable {
    case sleeping, drowsy, calm, happy, excited, celebrating, tired, charging

    var label: String {
        switch self {
        case .sleeping: "Asleep"
        case .drowsy: "Drowsy"
        case .calm: "Calm"
        case .happy: "Happy"
        case .excited: "Excited"
        case .celebrating: "Celebrating"
        case .tired: "Low energy"
        case .charging: "Recharging"
        }
    }
}

struct MoodInputs: Sendable {
    var date: Date
    var batteryLevel: Double?
    var isCharging: Bool = false
    var stepProgress: Double?
    var goalsComplete: Bool = false
    /// Minutes since the step count last increased, if known.
    var minutesSinceStepChange: Double?
    var calendar: Calendar = .current
}

/// Pure, testable mapping from device + activity state to a companion mood.
/// Each character's personality shifts the thresholds.
enum MoodEngine {
    static let lowBattery = 0.2

    static func mood(for c: CharacterDefinition, _ i: MoodInputs) -> Mood {
        let p = c.personality
        let hour = i.calendar.component(.hour, from: i.date)

        if i.isCharging { return .charging }
        if let level = i.batteryLevel, level >= 0, level <= lowBattery { return .tired }
        if i.goalsComplete || (i.stepProgress ?? 0) >= 1 { return .celebrating }

        let night = p.nightOwl ? (7..<10).contains(hour) : (hour >= 23 || hour < 6)
        if night { return p.sleepiness >= 0.6 ? .sleeping : .drowsy }

        if p.sleepsWhenIdle, let quiet = i.minutesSinceStepChange, quiet >= 30 { return .sleeping }

        let progress = i.stepProgress ?? 0
        if p.stepLover && progress >= 0.8 { return .excited }
        if progress >= 0.8 && p.energy >= 0.6 { return .excited }
        if progress >= 0.5 { return .happy }

        let evening = p.nightOwl ? false : (hour >= 21)
        if evening && p.sleepiness >= 0.4 { return .drowsy }
        if p.nightOwl && (hour >= 21 || hour < 3) { return .happy }
        if (6..<9).contains(hour) && p.sleepiness >= 0.7 { return .drowsy }
        return .calm
    }
}
