import Foundation

struct BatterySnapshot: Codable, Equatable, Sendable {
    enum State: String, Codable, Sendable { case unknown, unplugged, charging, full }

    /// 0…1, or nil when the platform does not report a level (e.g. some simulators).
    var level: Double?
    var state: State
    var isLowPower: Bool

    static let unknown = BatterySnapshot(level: nil, state: .unknown, isLowPower: false)

    var isCharging: Bool { state == .charging || state == .full }
    var isLow: Bool { (level ?? 1) <= MoodEngine.lowBattery && !isCharging }
    var percentText: String {
        guard let level else { return "--" }
        return "\(Int((level * 100).rounded()))%"
    }
}
