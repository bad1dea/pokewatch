import Foundation

enum AnimationIntensity: String, CaseIterable, Codable, Sendable, Identifiable {
    case calm, balanced, lively
    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: "Calm"
        case .balanced: "Balanced"
        case .lively: "Lively"
        }
    }

    var framesPerSecond: Double {
        switch self {
        case .calm: 8
        case .balanced: 15
        case .lively: 30
        }
    }

    var motionScale: Double {
        switch self {
        case .calm: 0.6
        case .balanced: 1
        case .lively: 1.25
        }
    }
}

/// Alternate idle routines, cycled with a double tap.
enum AnimationVariant: String, CaseIterable, Codable, Sendable {
    case idle, play, dance, wander

    var title: String {
        switch self {
        case .idle: "Idle"
        case .play: "Play"
        case .dance: "Dance"
        case .wander: "Wander"
        }
    }

    var next: AnimationVariant {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// Decides how often to redraw. Animation is the single biggest battery cost of a
/// face like this, so the frame rate adapts to settings, Low Power Mode,
/// Reduce Motion and how recently the user engaged.
struct MotionPolicy: Equatable, Sendable {
    var intensity: AnimationIntensity
    var reducedMotion: Bool
    var lowPower: Bool

    /// Seconds after a wake / interaction during which full frame rate is used.
    static let engagementWindow: TimeInterval = 20

    func framesPerSecond(secondsSinceEngagement: TimeInterval) -> Double {
        if reducedMotion { return 4 }               // blinks + seconds only, no movement
        var fps = intensity.framesPerSecond
        if lowPower { fps = min(fps, 6) }
        if secondsSinceEngagement > Self.engagementWindow { fps = max(4, (fps / 2).rounded()) }
        return fps
    }

    var motionScale: Double {
        if reducedMotion { return 0 }
        return intensity.motionScale * (lowPower ? 0.7 : 1)
    }

    var particlesEnabled: Bool { !reducedMotion && !lowPower }
}
