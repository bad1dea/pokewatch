import Foundation
import HealthKit

/// Read-only HealthKit queries shared by the app and the widget extension.
/// No writes, no workouts, no continuous sampling.
enum HealthQueries {
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static func readTypes(includeHeartRate: Bool) -> Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKObjectType.activitySummaryType(),
        ]
        if includeHeartRate { types.insert(HKQuantityType(.heartRate)) }
        return types
    }

    /// Cumulative sum for today (midnight → now). Returns nil when unauthorized or empty.
    static func todaySum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, store: HKHealthStore,
                         now: Date = Date(), calendar: Calendar = .current) async -> Double? {
        let type = HKQuantityType(id)
        let start = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let descriptor = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: type, predicate: predicate),
                                                     options: .cumulativeSum)
        guard let stats = try? await descriptor.result(for: store) else { return nil }
        return stats.sumQuantity()?.doubleValue(for: unit)
    }

    static func todayActivitySummary(store: HKHealthStore, now: Date = Date(),
                                     calendar: Calendar = .current) async -> HKActivitySummary? {
        var comps = calendar.dateComponents([.era, .year, .month, .day], from: now)
        comps.calendar = calendar
        let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: comps, end: comps)
        return await withCheckedContinuation { cont in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, _ in
                cont.resume(returning: summaries?.first)
            }
            store.execute(query)
        }
    }

    /// Most recent heart-rate sample from the last two hours. One-shot; never streams.
    static func latestHeartRate(store: HKHealthStore, now: Date = Date()) async -> Double? {
        let type = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: now.addingTimeInterval(-7200), end: now)
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: type, predicate: predicate)],
                                                 sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                                                 limit: 1)
        guard let sample = try? await descriptor.result(for: store).first else { return nil }
        return sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
    }

    static func todaySteps(store: HKHealthStore, now: Date = Date()) async -> Int? {
        guard let v = await todaySum(.stepCount, unit: .count(), store: store, now: now) else { return nil }
        return Int(v)
    }

    static func snapshot(store: HKHealthStore, includeHeartRate: Bool, now: Date = Date()) async -> ActivitySnapshot {
        async let steps = todaySum(.stepCount, unit: .count(), store: store, now: now)
        async let energy = todaySum(.activeEnergyBurned, unit: .kilocalorie(), store: store, now: now)
        async let exercise = todaySum(.appleExerciseTime, unit: .minute(), store: store, now: now)
        async let summary = todayActivitySummary(store: store, now: now)
        var snap = ActivitySnapshot()
        snap.steps = await steps.map { Int($0) }
        snap.activeEnergy = await energy
        snap.exerciseMinutes = await exercise
        if let s = await summary {
            snap.activeEnergy = s.activeEnergyBurned.doubleValue(for: .kilocalorie())
            snap.moveGoal = s.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie())
            snap.exerciseMinutes = s.appleExerciseTime.doubleValue(for: .minute())
            snap.exerciseGoal = s.exerciseTimeGoal?.doubleValue(for: .minute())
            snap.standHours = s.appleStandHours.doubleValue(for: .count())
            snap.standGoal = s.standHoursGoal?.doubleValue(for: .count())
        }
        if includeHeartRate { snap.heartRate = await latestHeartRate(store: store, now: now) }
        snap.updated = now
        return snap
    }
}
