import SwiftUI
import WidgetKit

/// Sprite rendered for the widget's rendering mode: the imported still (first frame of the
/// chosen generation) when bundled, else the fallback pixel art. In tinted / vibrant modes
/// the system recolours content, so a grey-shaded version reads better than full colour.
struct WidgetSprite: View {
    @Environment(\.widgetRenderingMode) private var mode
    let character: CharacterDefinition
    let mood: Mood
    var art = ArtChoice()
    /// Longest side in points.
    var side: CGFloat

    private static let greys = ["#FFFFFF", "#D0D0D0", "#8A8A8A", "#4A4A4A"].compactMap(RGB.init(hex:))

    var body: some View {
        if let still = WidgetStills.image(id: character.id, art: art) {
            let image = mode == .fullColor ? still : (ImageRecolor.shades(still, Self.greys) ?? still)
            let k = side / CGFloat(max(still.width, still.height))
            Image(decorative: image, scale: 1).resizable().interpolation(.none)
                .frame(width: CGFloat(still.width) * k, height: CGFloat(still.height) * k)
                .widgetAccentable(mode != .fullColor)
        } else {
            let expression: SpriteExpression = switch mood {
            case .sleeping: .closed
            case .drowsy, .tired: .tired
            case .happy, .excited, .celebrating, .charging: .happy
            case .calm: .open
            }
            let px = max(1, (side / CGFloat(max(character.width, character.height, 1))).rounded(.down))
            if mode == .fullColor {
                SpriteImage(character: character, expression: expression, pixel: px)
            } else {
                SpriteImage(character: character, expression: expression, tint: .shades(Self.greys), pixel: px)
                    .widgetAccentable()
            }
        }
    }
}

enum WidgetStills {
    nonisolated(unsafe) private static var cache: [String: CGImage] = [:]
    private static let lock = NSLock()

    static func image(id: String, art: ArtChoice) -> CGImage? {
        guard let (style, shiny) = SpriteFiles.resolve(id: id, style: art.style, shiny: art.shiny, exists: {
            SpriteFiles.stillURL(id: $0, style: $1, shiny: $2) != nil
        }), let url = SpriteFiles.stillURL(id: id, style: style, shiny: shiny) else { return nil }
        lock.lock(); defer { lock.unlock() }
        if let hit = cache[url.path] { return hit }
        let image = SpriteFiles.loadImage(url)
        cache[url.path] = image
        return image
    }
}

struct CompanionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CompanionEntry

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryCorner: corner
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        default: circular
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let p = entry.stepProgress {
                Circle().inset(by: 2).trim(from: 0, to: p)
                    .stroke(entry.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .widgetAccentable()
            }
            WidgetSprite(character: entry.character, mood: entry.mood, art: entry.art, side: 34)
        }
        .accessibilityLabel("\(entry.character.name), \(entry.mood.label)")
    }

    private var corner: some View {
        WidgetSprite(character: entry.character, mood: entry.mood, art: entry.art, side: 26)
            .widgetLabel {
                if let battery = entry.battery, let level = battery.level {
                    Gauge(value: level) { Text("Battery") } currentValueLabel: { Text(battery.percentText) }
                        .tint(entry.accent)
                } else {
                    Text("\(entry.character.name) · \(entry.mood.label)")
                }
            }
    }

    private var rectangular: some View {
        HStack(spacing: 6) {
            WidgetSprite(character: entry.character, mood: entry.mood, art: entry.art, side: 44)
                .frame(width: 46)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.character.name)
                    .font(.headline)
                    .widgetAccentable()
                Text(entry.mood.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    if let battery = entry.battery {
                        HStack(spacing: 2) {
                            PokeballGlyph(level: battery.level, isCharging: battery.isCharging, accent: entry.accent, size: 11)
                            Text(battery.percentText)
                        }
                    }
                    if let steps = entry.steps {
                        Text("\(steps.compactSteps) steps")
                    }
                }
                .font(.caption2.monospacedDigit())
            }
            Spacer(minLength: 0)
        }
    }

    private var inline: some View {
        if let steps = entry.steps {
            Text("\(entry.character.name) · \(entry.mood.label) · \(steps.compactSteps)")
        } else {
            Text("\(entry.character.name) · \(entry.mood.label)")
        }
    }
}

struct StepsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CompanionEntry

    var body: some View {
        let progress = entry.stepProgress ?? 0
        switch family {
        case .accessoryCorner:
            WidgetSprite(character: entry.character, mood: entry.mood, art: entry.art, side: 22)
                .widgetLabel {
                    Gauge(value: progress) { Text("Steps") } currentValueLabel: {
                        Text(entry.steps.map { $0.compactSteps } ?? "--")
                    }
                    .tint(entry.accent)
                }
        default:
            Gauge(value: progress) {
                Text("Steps")
            } currentValueLabel: {
                WidgetSprite(character: entry.character, mood: entry.mood, art: entry.art, side: 22)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(entry.accent)
            .accessibilityLabel(entry.steps.map { "\($0) steps" } ?? "Steps unavailable")
        }
    }
}

#Preview("Circular", as: .accessoryCircular) { CompanionWidget() } timeline: { CompanionEntry.placeholder() }
#Preview("Rectangular", as: .accessoryRectangular) { CompanionWidget() } timeline: { CompanionEntry.placeholder() }
#Preview("Corner", as: .accessoryCorner) { CompanionWidget() } timeline: { CompanionEntry.placeholder() }
#Preview("Inline", as: .accessoryInline) { CompanionWidget() } timeline: { CompanionEntry.placeholder() }
