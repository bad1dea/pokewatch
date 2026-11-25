import Foundation

/// Everything needed to draw the companion for one frame. Units are sprite pixels.
struct CompanionPose: Equatable, Sendable {
    var expression: SpriteExpression = .open
    var dx: Double = 0
    var dy: Double = 0
    var scaleX: Double = 1
    var scaleY: Double = 1
    var rotation: Double = 0       // degrees, anchored at the feet
    var flipped = false
    var earTwitch = false
    var showsZ = false
    var particleLevel: Double = 0  // 0…1
    var speech: String?
    /// Speed multiplier for imported animations; 0 shows the still first frame.
    var playbackRate: Double = 1
}

struct AnimationInput: Sendable {
    var time: TimeInterval
    var mood: Mood
    var variant: AnimationVariant = .idle
    var motionScale: Double = 1
    var wakeElapsed: TimeInterval?
    var reactionElapsed: TimeInterval?
    var dimmed = false
    /// The art animates itself (imported GIF/APNG): body motion is toned down so it
    /// doesn't fight the sprite's own animation.
    var animatedArt = false
}

/// Pure function from (character, time, mood) to a pose. No timers, no state:
/// the face's TimelineView supplies the time, so a paused timeline costs nothing.
enum CompanionAnimator {
    static let wakeDuration: TimeInterval = 1.6
    static let reactionDuration: TimeInterval = 1.4

    static func pose(_ c: CharacterDefinition, _ i: AnimationInput) -> CompanionPose {
        var p = basePose(c, i)
        if i.animatedArt {
            // Keep hops and squash; damp idle sway and bob.
            if p.dy > -1.2 * i.motionScale { p.dy *= 0.3 }
            p.dx *= 0.3
            p.rotation *= 0.3
        }
        if i.motionScale == 0 && p.playbackRate > 0 { p.playbackRate = 0 }   // Reduce Motion: still frame
        return p
    }

    static func basePose(_ c: CharacterDefinition, _ i: AnimationInput) -> CompanionPose {
        if i.dimmed { return restingPose() }
        if let w = i.wakeElapsed, w >= 0, w < wakeDuration { return wakePose(c, w, i.motionScale) }
        if let r = i.reactionElapsed, r >= 0, r < reactionDuration { return reactionPose(c, r, i) }

        let p = c.personality
        let t = i.time
        let m = i.motionScale
        var pose = CompanionPose()

        switch i.mood {
        case .sleeping:
            return sleepingPose(c, t, m)
        case .tired:
            pose = idle(p.idleStyle, t, speed: p.bobSpeed * 0.5, amp: p.bobAmplitude * 0.4 * m)
            pose.expression = .tired
            pose.playbackRate = 0.55
            pose.scaleY *= 0.96
            pose.dy += 0.5
            return pose
        case .drowsy:
            pose = idle(p.idleStyle, t, speed: p.bobSpeed * 0.6, amp: p.bobAmplitude * 0.6 * m)
            let nod = t.truncatingRemainder(dividingBy: 9)
            pose.expression = nod > 6.5 ? .closed : .tired
            if nod > 6.5 { pose.dy += 0.6 * m }
            pose.particleLevel = 0.1
            pose.playbackRate = nod > 6.5 ? 0 : 0.6
        case .calm:
            pose = idle(p.idleStyle, t, speed: p.bobSpeed, amp: p.bobAmplitude * m)
            pose.particleLevel = 0.25
        case .happy:
            pose = idle(p.idleStyle, t, speed: p.bobSpeed * 1.15, amp: p.bobAmplitude * 1.15 * m)
            if t.truncatingRemainder(dividingBy: 6) > 5 { pose.expression = .happy }
            pose.particleLevel = 0.4
        case .excited:
            pose = idle(p.idleStyle, t, speed: p.bobSpeed * 1.6, amp: p.bobAmplitude * 1.4 * m)
            let h = hop(t, period: 2.2, length: 0.45, height: p.hopHeight * m)
            pose.dy -= h
            if h > 0 { pose.expression = .happy }
            pose.particleLevel = 0.7
            pose.playbackRate = 1.4
        case .celebrating:
            pose = idle(p.idleStyle, t, speed: p.bobSpeed * 1.4, amp: p.bobAmplitude * m)
            let h = hop(t, period: 1.1, length: 0.5, height: p.hopHeight * 1.2 * m)
            pose.dy -= h
            pose.rotation += sin(t * 7) * 4 * m
            pose.expression = h > 0 || t.truncatingRemainder(dividingBy: 3) < 2 ? .happy : .open
            pose.particleLevel = 1
            pose.playbackRate = 1.5
        case .charging:
            pose = idle(p.idleStyle, t, speed: p.bobSpeed, amp: p.bobAmplitude * m)
            if t.truncatingRemainder(dividingBy: 4) > 3.2 { pose.expression = .happy }
            pose.particleLevel = 0.8
        }

        applyVariant(i.variant, to: &pose, c, t, m)

        if pose.expression == .open && isBlinking(t, interval: p.blinkInterval, seed: c.seed) {
            pose.expression = .closed
        }
        return pose
    }

    // MARK: - Building blocks

    /// Static pose for Always-On: eyes closed, settled lower, no movement.
    static func restingPose() -> CompanionPose {
        CompanionPose(expression: .closed, dy: 0.5, scaleX: 1.02, scaleY: 0.95, showsZ: true, playbackRate: 0)
    }

    static func sleepingPose(_ c: CharacterDefinition, _ t: TimeInterval, _ m: Double) -> CompanionPose {
        var pose = CompanionPose()
        pose.expression = .closed
        let breath = sin(t * 1.6)
        pose.scaleY = 0.95 + 0.03 * breath * max(m, 0.4)
        pose.scaleX = 1.02 - 0.012 * breath * max(m, 0.4)
        pose.dy = 0.5
        // An ear flick every few seconds, at pseudo-random intervals.
        let slot = floor(t / 5.5)
        pose.earTwitch = noise(slot, c.seed) > 0.55 && (t - slot * 5.5) < 0.35
        pose.showsZ = true
        pose.particleLevel = 0.3
        pose.playbackRate = 0
        return pose
    }

    static func wakePose(_ c: CharacterDefinition, _ w: TimeInterval, _ m: Double) -> CompanionPose {
        var pose = CompanionPose(speech: c.lines.wake)
        switch w {
        case ..<0.45:
            pose.expression = .closed
            pose.playbackRate = 0
            let k = w / 0.45
            pose.scaleY = 0.95 + 0.11 * sin(k * .pi) * max(m, 0.3)   // stretch
            pose.scaleX = 1.02 - 0.04 * sin(k * .pi) * max(m, 0.3)
        case ..<0.65:
            pose.expression = .tired
            pose.playbackRate = 0
        case ..<0.85: pose.expression = .open
        case ..<0.97: pose.expression = .closed
        default:
            pose.expression = .happy
            let k = (w - 0.97) / (wakeDuration - 0.97)
            pose.dy = -sin(min(1, k * 1.4) * .pi) * c.personality.hopHeight * 0.8 * m
            pose.particleLevel = 0.6
        }
        return pose
    }

    static func reactionPose(_ c: CharacterDefinition, _ r: TimeInterval, _ i: AnimationInput) -> CompanionPose {
        let p = c.personality
        var pose = CompanionPose()
        let k = min(1, r / 0.6)
        let height = p.hopHeight * (0.6 + 0.4 * p.energy) * i.motionScale
        pose.dy = -sin(k * .pi) * height
        if r < 0.6 { pose.scaleY = 1 + 0.06 * sin(k * .pi) * i.motionScale }
        pose.expression = (i.mood == .tired || i.mood == .sleeping) && r > 0.8 ? .tired : .happy
        pose.particleLevel = 0.9
        pose.playbackRate = 1.5
        pose.speech = i.mood == .sleeping ? c.lines.wake : c.line(for: i.mood == .calm ? .happy : i.mood)
        return pose
    }

    static func idle(_ style: IdleStyle, _ t: TimeInterval, speed: Double, amp: Double) -> CompanionPose {
        var pose = CompanionPose()
        switch style {
        case .bounce:
            pose.dy = -abs(sin(t * speed * .pi / 2)) * amp * 1.5
            pose.scaleY = 1 + 0.015 * sin(t * speed * .pi) * amp
        case .sway:
            pose.rotation = sin(t * speed) * 3.5 * amp
            pose.dx = sin(t * speed) * 0.4 * amp
        case .float:
            pose.dy = sin(t * speed) * amp * 1.2 - amp
            pose.rotation = sin(t * speed * 0.5) * 2 * amp
        case .breathe:
            pose.scaleY = 1 + 0.03 * sin(t * speed * 2) * max(amp, 0.3)
            pose.scaleX = 1 - 0.012 * sin(t * speed * 2) * max(amp, 0.3)
        case .waddle:
            pose.rotation = sin(t * speed * 2) * 4 * amp
            pose.dy = -abs(sin(t * speed * 2)) * 0.8 * amp
        case .wobble:
            pose.rotation = sin(t * speed) * 6 * amp
            pose.dx = sin(t * speed * 0.5) * 0.5 * amp
        }
        return pose
    }

    static func applyVariant(_ v: AnimationVariant, to pose: inout CompanionPose,
                             _ c: CharacterDefinition, _ t: TimeInterval, _ m: Double) {
        guard m > 0 else { return }
        switch v {
        case .idle: break
        case .play:
            let h = hop(t, period: 2.6, length: 0.5, height: c.personality.hopHeight * m)
            pose.dy -= h
            if h > 0 { pose.expression = .happy }
        case .dance:
            pose.flipped = Int(floor(t / 0.6)) % 2 == 0
            pose.rotation += sin(t * 6) * 7 * m
            pose.dy -= abs(sin(t * 5.2)) * 1.2 * m
        case .wander:
            pose.dx += sin(t * 0.55) * 7 * m
            pose.flipped = cos(t * 0.55) < 0
            pose.dy -= abs(sin(t * 6)) * 0.8 * m
        }
    }

    /// Height of a periodic hop at time t (0 outside the hop window).
    static func hop(_ t: TimeInterval, period: Double, length: Double, height: Double) -> Double {
        let phase = t.truncatingRemainder(dividingBy: period)
        guard phase < length else { return 0 }
        return sin(phase / length * .pi) * height
    }

    static func isBlinking(_ t: TimeInterval, interval: Double, seed: Int) -> Bool {
        let interval = max(1.5, interval)
        let cycle = floor(t / interval)
        let start = cycle * interval + noise(cycle, seed) * interval * 0.5
        let d = t - start
        if d >= 0 && d < 0.16 { return true }
        // Occasional double blink.
        if noise(cycle + 0.5, seed) > 0.75 && d >= 0.3 && d < 0.44 { return true }
        return false
    }

    /// Deterministic hash noise in 0..<1.
    static func noise(_ n: Double, _ seed: Int) -> Double {
        let v = sin(n * 12.9898 + Double(seed) * 78.233) * 43758.5453
        return v - floor(v)
    }
}
