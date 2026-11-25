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

extension FaceOptions {
    @MainActor
    init(_ s: SettingsStore) {
        self.init(use24h: s.use24Hour, showSeconds: s.showSeconds, showDate: s.showDate, showBattery: s.showBattery,
                  showActivity: s.showActivity && s.useHealth, accent: s.accent, retroPalette: s.retroPalette,
                  analogSeconds: s.analogSeconds, aod: s.aodAppearance, stepGoal: s.stepGoal)
    }
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
    var art = ArtChoice()

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

/// Corner-safe geometry for a face of size `size` (see `ScreenShape`).
struct FaceFrame {
    let size: CGSize
    var W: CGFloat { size.width }
    var H: CGFloat { size.height }
    /// Horizontal inset for content spanning `minY...maxY` from the top.
    func inset(_ minY: CGFloat, _ maxY: CGFloat) -> CGFloat {
        max(10, ScreenShape.inset(forBand: minY, maxY, screenHeight: H))
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
                       dimmed: Bool = false, style: FaceStyle = .electric, options: FaceOptions = FaceOptions(),
                       art: ArtChoice = ArtChoice(), variant: AnimationVariant = .idle) -> FaceContext {
        let c = CharacterRegistry.shared.character(characterID)
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 86_400)
        let animated = SpriteLibrary.shared.clip(for: c.id, style: art.style, shiny: art.shiny).map { !$0.isStill } ?? false
        return FaceContext(date: date, time: t, dimmed: dimmed, character: c,
                           pose: CompanionAnimator.pose(c, AnimationInput(time: t, mood: dimmed ? .sleeping : mood,
                                                                          variant: variant, dimmed: dimmed,
                                                                          animatedArt: animated)),
                           mood: dimmed ? .sleeping : mood,
                           battery: BatterySnapshot(level: 0.72, state: .unplugged, isLowPower: false),
                           activity: .demo, options: options, particlesEnabled: true, variant: variant, art: art)
    }
}
