import SwiftUI

/// Drives the selected face with the right timeline for the current display state.
///
/// * Active: `TimelineView(.animation)` at an adaptive frame rate, paused unless the
///   scene is active.
/// * Always-On (`isLuminanceReduced`): `TimelineView(.everyMinute)` with a static
///   sleeping pose — the system decides when (and whether) to actually redraw.
struct FaceHost: View {
    @Environment(AppModel.self) private var model
    @Environment(\.isLuminanceReduced) private var luminanceReduced
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    /// Becomes true once the engagement window after a wake/tap has passed,
    /// which halves the frame rate until the next interaction.
    @State private var settled = false

    var style: FaceStyle? = nil

    var body: some View {
        let dimmed = luminanceReduced || model.launch.forceDimmed
        let face = style ?? model.settings.faceStyle
        Group {
            if dimmed {
                TimelineView(.everyMinute) { tl in
                    FaceView(style: face, context: model.faceContext(at: tl.date, style: face, dimmed: true,
                                                                     systemReduceMotion: systemReduceMotion))
                }
            } else {
                let policy = model.motionPolicy(systemReduceMotion: systemReduceMotion)
                let fps = policy.framesPerSecond(secondsSinceEngagement: settled ? .infinity : 0)
                TimelineView(.animation(minimumInterval: 1 / fps, paused: scenePhase != .active)) { tl in
                    FaceView(style: face,
                             context: model.faceContext(at: tl.date, style: face, dimmed: false,
                                                        systemReduceMotion: systemReduceMotion),
                             onTapCompanion: { model.tapCompanion() })
                }
            }
        }
        .task(id: model.lastEngagement) {
            settled = false
            try? await Task.sleep(for: .seconds(MotionPolicy.engagementWindow))
            if !Task.isCancelled { settled = true }
        }
    }
}

extension AppModel {
    func motionPolicy(systemReduceMotion: Bool) -> MotionPolicy {
        var p = motionPolicy
        p.reducedMotion = p.reducedMotion || systemReduceMotion
        return p
    }

    /// Builds the per-frame face context. Cheap: no allocation beyond small structs,
    /// sprite images come from the rasterizer cache.
    func faceContext(at realDate: Date, style: FaceStyle, dimmed: Bool, systemReduceMotion: Bool) -> FaceContext {
        let policy = motionPolicy(systemReduceMotion: systemReduceMotion)
        let c = character
        let baseMood = mood(now: realDate)
        let mood: Mood = dimmed || (style == .sleeping && launch.mood == nil) ? .sleeping : baseMood
        let t = realDate.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 86_400)
        // The Yellow face uses Gen I art; Pokémon from later generations keep the chosen style
        // (drawn in the face's four shades).
        let yellowGen1 = style == .yellow && registry.isAvailable(c.id, in: .gen1)
        let art = ArtChoice(style: yellowGen1 ? .gen1 : settings.spriteStyle, shiny: settings.shiny)
        let clip = SpriteLibrary.shared.clip(for: c.id, style: art.style, shiny: art.shiny)
        let input = AnimationInput(time: t, mood: mood, variant: settings.variant, motionScale: policy.motionScale,
                                   wakeElapsed: wakeStart.map { realDate.timeIntervalSince($0) },
                                   reactionElapsed: reactionStart.map { realDate.timeIntervalSince($0) },
                                   dimmed: dimmed, animatedArt: clip.map { !$0.isStill } ?? false)
        let options = FaceOptions(use24h: settings.use24Hour, showSeconds: settings.showSeconds,
                                  showDate: settings.showDate, showBattery: settings.showBattery,
                                  showActivity: settings.showActivity && settings.useHealth,
                                  accent: settings.accent, retroPalette: settings.retroPalette,
                                  analogSeconds: settings.analogSeconds, aod: settings.aodAppearance,
                                  stepGoal: settings.stepGoal)
        return FaceContext(date: launch.displayDate(realDate), time: t, dimmed: dimmed, character: c,
                           pose: CompanionAnimator.pose(c, input), mood: mood, battery: battery.snapshot,
                           activity: health.snapshot, options: options,
                           particlesEnabled: policy.particlesEnabled, variant: settings.variant,
                           motionScale: policy.motionScale, art: art)
    }
}

/// Static context for SwiftUI previews and tests.
struct FacePreview: View {
    var style: FaceStyle
    var dimmed = false
    var characterID = "pikachu"
    var mood: Mood = .happy

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15)) { tl in
            FaceView(style: style, context: .sample(date: tl.date, characterID: characterID, mood: mood, dimmed: dimmed))
        }
    }
}

extension FaceContext {
    static func sample(date: Date = Date(), characterID: String = "pikachu", mood: Mood = .happy,
                       dimmed: Bool = false, style: FaceStyle = .electric) -> FaceContext {
        let c = CharacterRegistry.shared.character(characterID)
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 86_400)
        return FaceContext(date: date, time: t, dimmed: dimmed, character: c,
                           pose: CompanionAnimator.pose(c, AnimationInput(time: t, mood: mood, dimmed: dimmed)),
                           mood: mood, battery: BatterySnapshot(level: 0.72, state: .unplugged, isLowPower: false),
                           activity: .demo, options: FaceOptions(), particlesEnabled: true)
    }
}
