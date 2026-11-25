import Foundation
import Observation
import SwiftUI
import WatchKit
import WidgetKit

/// Owns long-lived services and the small amount of transient interaction state.
/// Per-frame values (pose, clock) are computed from this inside the face's TimelineView,
/// so nothing here changes 30 times a second.
@MainActor @Observable
final class AppModel {
    let settings: SettingsStore
    let battery: BatteryMonitor
    let health: HealthService
    let registry: CharacterRegistry
    let launch: LaunchOptions
    let sync = SyncService()
    /// Sprite packs installed from the iPhone.
    private(set) var installedPacks: [SpritePackKind] = []
    private(set) var installingPack: SpritePackKind?

    /// When the most recent wake-up animation started (wrist raise / AOD exit / launch).
    private(set) var wakeStart: Date?
    /// When the companion was last tapped.
    private(set) var reactionStart: Date?
    /// Last wake or touch; drives the adaptive frame rate.
    private(set) var lastEngagement = Date()

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var lastReloadedSteps: Int?
    @ObservationIgnored private var lastWidgetReload: Date?

    init(launch: LaunchOptions = .current, defaults: UserDefaults = .standard) {
        self.launch = launch
        settings = SettingsStore(defaults: defaults)
        settings.applyLaunchOverrides(launch)
        battery = BatteryMonitor(demo: launch.demo ? BatterySnapshot(level: 0.72, state: .unplugged, isLowPower: false) : nil)
        health = HealthService(demo: launch.demo ? .demo : nil)
        registry = .shared
        if !registry.contains(settings.characterID) { settings.characterID = registry.characters.first?.id ?? "pikachu" }
        installedPacks = SpritePackStore.installed
        SpriteFiles.extraRoots = SpritePackStore.spriteRoots
        connectPhone()
    }

    // MARK: - iPhone link

    private func connectPhone() {
        guard !launch.demo else { return }
        settings.onLocalChange = { [weak self] in self?.publishToPhone() }
        sync.onSettings = { [weak self] payload in
            guard let self, self.settings.apply(syncPayload: payload) else { return }
            self.wake()
            self.refreshComplications(force: true)
        }
        sync.onPack = { [weak self] kind, file in self?.install(pack: kind, from: file) }
        sync.activate()
        publishToPhone()
    }

    private func publishToPhone() {
        sync.publish(settings: settings.syncPayload, installedPacks: installedPacks)
    }

    private func install(pack kind: SpritePackKind, from file: URL) {
        installingPack = kind
        Task.detached(priority: .utility) {
            let result = Result { try SpritePackStore.install(archive: file, kind: kind) }
            try? FileManager.default.removeItem(at: file)
            await MainActor.run {
                self.installingPack = nil
                if case .success = result {
                    self.installedPacks = SpritePackStore.installed
                    SpriteFiles.extraRoots = SpritePackStore.spriteRoots
                    SpriteLibrary.shared.reset()
                    self.publishToPhone()
                }
            }
        }
    }

    var character: CharacterDefinition { registry.character(settings.characterID) }

    func moodInputs(now: Date) -> MoodInputs {
        let a = health.snapshot
        return MoodInputs(date: now,
                          batteryLevel: battery.snapshot.level,
                          isCharging: battery.snapshot.isCharging,
                          stepProgress: settings.useHealth ? a.stepProgress(goal: settings.stepGoal) : nil,
                          goalsComplete: settings.useHealth && a.ringsClosed,
                          minutesSinceStepChange: settings.useHealth ? health.minutesSinceStepChange(now: now) : nil)
    }

    func mood(now: Date) -> Mood {
        if let forced = launch.mood { return forced }
        return MoodEngine.mood(for: character, moodInputs(now: now))
    }

    var motionPolicy: MotionPolicy {
        MotionPolicy(intensity: settings.intensity,
                     reducedMotion: settings.reducedMotion,
                     lowPower: battery.snapshot.isLowPower)
    }

    // MARK: - Lifecycle

    func becameActive() {
        wake()
        battery.refresh()
        startPeriodicRefresh()
        if settings.useHealth && !health.authorizationRequested && health.isAvailable && !launch.demo {
            Task { await health.requestAuthorization(includeHeartRate: settings.heartRate) }
        }
    }

    func becameInactive() {
        refreshTask?.cancel()
        refreshTask = nil
        refreshComplications(force: false)
    }

    /// One coarse refresh loop while active: battery every minute, Health at most every 3 minutes.
    private func startPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.battery.refresh()
                if self.settings.useHealth {
                    await self.health.refresh(includeHeartRate: self.settings.heartRate)
                }
                self.refreshComplications(force: false)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    // MARK: - Interaction

    func wake(at date: Date = Date()) {
        wakeStart = date
        lastEngagement = date
    }

    func tapCompanion(at date: Date = Date()) {
        reactionStart = date
        lastEngagement = date
        haptic(.click)
    }

    func cycleVariant() {
        settings.variant = settings.variant.next
        lastEngagement = Date()
        haptic(.directionUp)
    }

    func shiftFace(by offset: Int) {
        let all = FaceStyle.allCases
        let i = all.firstIndex(of: settings.faceStyle) ?? 0
        settings.faceStyle = all[((i + offset) % all.count + all.count) % all.count]
        wake()
        haptic(.click)
    }

    func selectCharacter(_ id: String) {
        guard id != settings.characterID else { return }
        settings.characterID = id
        wake()
        refreshComplications(force: true)
    }

    /// Favourites available in the current style, in favourite order; the current Pokémon is
    /// included even if it isn't a favourite, so the Crown wheel always starts from it.
    var crownRoster: [CharacterDefinition] {
        let style = settings.spriteStyle
        var ids = settings.favorites.filter { registry.isAvailable($0, in: style) }
        if !ids.contains(settings.characterID) { ids.insert(settings.characterID, at: 0) }
        return ids.map(registry.character)
    }

    /// Era-accurate styles: after switching to an older generation, a Pokémon that didn't
    /// exist yet is replaced by the first available favourite (or Pikachu).
    func styleChanged() {
        let style = settings.spriteStyle
        guard !registry.isAvailable(settings.characterID, in: style) else { return }
        let next = settings.favorites.first { registry.isAvailable($0, in: style) }
            ?? registry.available(in: style).first?.id ?? "pikachu"
        selectCharacter(next)
    }

    func haptic(_ type: WKHapticType) {
        guard settings.haptics else { return }
        WKInterfaceDevice.current().play(type)
    }

    // MARK: - Complications

    /// Complications read Health and battery themselves; the app only nudges WidgetKit
    /// when steps moved noticeably. Reloads are budgeted by the system, so they are
    /// throttled to one per ten minutes unless forced.
    func refreshComplications(force: Bool, now: Date = Date()) {
        let steps = health.snapshot.steps
        let moved = abs((steps ?? 0) - (lastReloadedSteps ?? 0)) >= 500
        let throttled = lastWidgetReload.map { now.timeIntervalSince($0) < 600 } ?? false
        guard force || (moved && !throttled) else { return }
        WidgetCenter.shared.reloadAllTimelines()
        lastWidgetReload = now
        lastReloadedSteps = steps
    }
}
