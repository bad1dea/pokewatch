import Foundation
import Observation
import WatchKit

/// Battery + Low Power Mode. Polled on demand (on activation and once a minute while
/// the face is active) — never with a high-frequency timer.
@MainActor @Observable
final class BatteryMonitor {
    private(set) var snapshot: BatterySnapshot = .unknown
    private(set) var lastRead: Date?
    private var demo: BatterySnapshot?
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(demo: BatterySnapshot? = nil) {
        self.demo = demo
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        observer = NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange,
                                                          object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    func refresh(now: Date = Date()) {
        if let demo { snapshot = demo; lastRead = now; return }
        let device = WKInterfaceDevice.current()
        let raw = device.batteryLevel
        let state: BatterySnapshot.State = switch device.batteryState {
        case .charging: .charging
        case .full: .full
        case .unplugged: .unplugged
        default: .unknown
        }
        let next = BatterySnapshot(level: raw >= 0 ? Double(raw) : nil, state: state,
                                   isLowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
        if next != snapshot { snapshot = next }
        lastRead = now
    }
}
