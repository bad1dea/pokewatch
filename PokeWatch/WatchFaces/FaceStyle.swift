import SwiftUI

enum FaceStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case electric, yellow, minimal, sleeping, pokedex, analog
    var id: String { rawValue }

    var number: String { String(format: "%02d", (Self.allCases.firstIndex(of: self) ?? 0) + 1) }

    var title: String {
        switch self {
        case .electric: "Electric"
        case .yellow: "Pokémon Yellow"
        case .minimal: "Minimal"
        case .sleeping: "Sleeping"
        case .pokedex: "Pokédex"
        case .analog: "Analog"
        }
    }
}

/// Face display options derived from settings.
struct FaceOptions: Sendable {
    var use24h = false
    var showSeconds = true
    var showDate = true
    var showBattery = true
    var showActivity = true
    var accent: AccentChoice = .electric
    var retroPalette: RetroPalette = .classicGreen
    var analogSeconds = true
    var aod: AODAppearance = .sleeping
    var stepGoal = 8000
}

/// Everything a face needs for one frame.
struct FaceContext {
    var date: Date
    var time: TimeInterval
    var dimmed: Bool
    var character: CharacterDefinition
    var pose: CompanionPose
    var mood: Mood
    var battery: BatterySnapshot
    var activity: ActivitySnapshot
    var options: FaceOptions
    var particlesEnabled: Bool
    var variant: AnimationVariant = .idle
    /// 0 when Reduce Motion is on.
    var motionScale: Double = 1

    var clock: ClockParts { ClockFormatter.parts(for: date, use24h: options.use24h) }
    var accent: Color { options.accent.color }
    /// Seconds are never shown in Always-On: the system updates at most once a minute there.
    var showSeconds: Bool { options.showSeconds && !dimmed }
    var showCompanion: Bool { !(dimmed && options.aod == .clockOnly) }

    /// Sprite tint for the current luminance state.
    func spriteTint(active: SpriteTint = .natural) -> SpriteTint {
        guard dimmed else { return active }
        switch options.aod {
        case .silhouette: return .silhouette(RGB(hex: options.accent.hex)!.scaled(0.32))
        default: return .dimmed(42)
        }
    }

    var stepProgress: Double? { activity.stepProgress(goal: options.stepGoal) }
}

/// Renders the selected style.
struct FaceView: View {
    let style: FaceStyle
    let context: FaceContext
    var onTapCompanion: () -> Void = {}

    var body: some View {
        Group {
            switch style {
            case .electric: ElectricFace(ctx: context, onTapCompanion: onTapCompanion)
            case .yellow: YellowFace(ctx: context, onTapCompanion: onTapCompanion)
            case .minimal: MinimalFace(ctx: context, onTapCompanion: onTapCompanion)
            case .sleeping: SleepingFace(ctx: context, onTapCompanion: onTapCompanion)
            case .pokedex: PokedexFace(ctx: context, onTapCompanion: onTapCompanion)
            case .analog: AnalogFace(ctx: context, onTapCompanion: onTapCompanion)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

extension View {
    /// Generous tap target around a sprite.
    func companionTapTarget(_ action: @escaping () -> Void) -> some View {
        contentShape(Rectangle().inset(by: -8))
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Tap to play with your Pokémon")
    }
}
