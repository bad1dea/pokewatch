import Foundation

/// Today's activity. Every field is optional: HealthKit may be unavailable,
/// unauthorized, or simply have no samples yet.
struct ActivitySnapshot: Codable, Equatable, Sendable {
    var steps: Int?
    var activeEnergy: Double?      // kcal
    var exerciseMinutes: Double?
    var moveGoal: Double?          // kcal
    var exerciseGoal: Double?      // minutes
    var standHours: Double?
    var standGoal: Double?
    var heartRate: Double?         // bpm, most recent sample only
    var updated: Date?

    static let empty = ActivitySnapshot()

    var hasData: Bool { steps != nil || activeEnergy != nil || exerciseMinutes != nil }

    func stepProgress(goal: Int) -> Double? {
        guard let steps, goal > 0 else { return nil }
        return Double(steps) / Double(goal)
    }

    var moveProgress: Double? { ratio(activeEnergy, moveGoal) }
    var exerciseProgress: Double? { ratio(exerciseMinutes, exerciseGoal) }
    var standProgress: Double? { ratio(standHours, standGoal) }

    /// All three rings closed (only when ring goals are known).
    var ringsClosed: Bool {
        guard let m = moveProgress, let e = exerciseProgress, let s = standProgress else { return false }
        return m >= 1 && e >= 1 && s >= 1
    }

    private func ratio(_ v: Double?, _ g: Double?) -> Double? {
        guard let v, let g, g > 0 else { return nil }
        return v / g
    }

    static let demo = ActivitySnapshot(steps: 6_482, activeEnergy: 412, exerciseMinutes: 24, moveGoal: 600,
                                       exerciseGoal: 30, standHours: 9, standGoal: 12, heartRate: 68, updated: Date())
}

extension Int {
    /// "6,482" / "12.4k"
    var compactSteps: String {
        if self >= 10_000 { return String(format: "%.1fk", Double(self) / 1000) }
        return formatted(.number.grouping(.automatic))
    }
}
