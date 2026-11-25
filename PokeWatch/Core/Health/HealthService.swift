import Foundation
import HealthKit
import Observation

/// Optional, read-only HealthKit integration. The app is fully usable without it:
/// every consumer treats `snapshot` fields as optional.
@MainActor @Observable
final class HealthService {
    private(set) var snapshot: ActivitySnapshot = .empty
    private(set) var lastStepChange: Date?
    private(set) var authorizationRequested = false

    @ObservationIgnored private let store: HKHealthStore?
    @ObservationIgnored private var lastFetch: Date?
    @ObservationIgnored private var inFlight = false
    @ObservationIgnored private let demo: ActivitySnapshot?

    /// Minimum spacing between query batches; HealthKit is not polled more often.
    static let minimumInterval: TimeInterval = 180

    var isAvailable: Bool { store != nil }

    init(demo: ActivitySnapshot? = nil) {
        self.demo = demo
        store = HealthQueries.isAvailable ? HKHealthStore() : nil
        if let demo {
            snapshot = demo
            lastStepChange = Date().addingTimeInterval(-300)
        }
    }

    /// Requests read access once. Denial is silent by design (HealthKit never reveals
    /// read authorization); queries simply come back empty.
    func requestAuthorization(includeHeartRate: Bool) async {
        guard let store, demo == nil else { return }
        authorizationRequested = true
        try? await store.requestAuthorization(toShare: [], read: HealthQueries.readTypes(includeHeartRate: includeHeartRate))
        await refresh(force: true, includeHeartRate: includeHeartRate)
    }

    func refresh(force: Bool = false, includeHeartRate: Bool, now: Date = Date()) async {
        guard let store, demo == nil, !inFlight else { return }
        if !force, let lastFetch, now.timeIntervalSince(lastFetch) < Self.minimumInterval { return }
        inFlight = true
        defer { inFlight = false }
        let next = await HealthQueries.snapshot(store: store, includeHeartRate: includeHeartRate, now: now)
        lastFetch = now
        if let s = next.steps, s != snapshot.steps { lastStepChange = now }
        if lastStepChange == nil { lastStepChange = now }
        snapshot = next
    }

    func minutesSinceStepChange(now: Date = Date()) -> Double? {
        guard let lastStepChange else { return nil }
        return now.timeIntervalSince(lastStepChange) / 60
    }
}
