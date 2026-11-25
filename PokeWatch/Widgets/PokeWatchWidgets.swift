import AppIntents
import HealthKit
import SwiftUI
import WatchKit
import WidgetKit

@main
struct PokeWatchWidgets: WidgetBundle {
    var body: some Widget {
        CompanionWidget()
        StepsWidget()
    }
}

// MARK: - Configuration

/// A selectable companion, listed from the same character files as the app.
struct PokemonEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Pokémon"
    static let defaultQuery = PokemonQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(_ c: CharacterDefinition) { id = c.id; name = c.name }
}

struct PokemonQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [PokemonEntity] {
        let q = string.trimmingCharacters(in: .whitespaces)
        return CharacterRegistry.shared.characters
            .filter { q.isEmpty || $0.name.localizedCaseInsensitiveContains(q) || "\($0.dexNumber)" == q }
            .map(PokemonEntity.init)
    }

    func entities(for identifiers: [String]) async throws -> [PokemonEntity] {
        CharacterRegistry.shared.characters.filter { identifiers.contains($0.id) }.map(PokemonEntity.init)
    }

    /// The hand-tuned companions first; the rest are reachable by search.
    func suggestedEntities() async throws -> [PokemonEntity] {
        let registry = CharacterRegistry.shared
        return CharacterRegistry.builtInOrder.filter(registry.contains).map { PokemonEntity(registry.character($0)) }
    }

    func defaultResult() async -> PokemonEntity? {
        CharacterRegistry.shared.characters.first.map(PokemonEntity.init)
    }
}

enum SpriteStyleOption: String, AppEnum {
    case gen1, gen2, gen3, gen4, gen5, modern
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Sprites"
    static let caseDisplayRepresentations: [SpriteStyleOption: DisplayRepresentation] = [
        .gen1: "Gen I", .gen2: "Gen II", .gen3: "Gen III", .gen4: "Gen IV", .gen5: "Gen V", .modern: "Modern",
    ]
    var style: SpriteStyle { SpriteStyle(rawValue: rawValue) ?? .default }
}

struct CompanionConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Pokémon"
    static let description = IntentDescription("Choose the Pokémon shown in this complication.")

    @Parameter(title: "Pokémon")
    var pokemon: PokemonEntity?

    @Parameter(title: "Daily step goal", default: 8000, controlStyle: .field, inclusiveRange: (1000, 30000))
    var stepGoal: Int

    @Parameter(title: "Sprites", default: .gen5)
    var sprites: SpriteStyleOption

    @Parameter(title: "Shiny", default: false)
    var shiny: Bool

    init() {}

    init(pokemon: PokemonEntity, stepGoal: Int = 8000) {
        self.pokemon = pokemon
        self.stepGoal = stepGoal
    }
}

// MARK: - Timeline

struct CompanionEntry: TimelineEntry {
    let date: Date
    let character: CharacterDefinition
    let mood: Mood
    let battery: BatterySnapshot?
    let steps: Int?
    let stepGoal: Int
    let accent: Color
    var art = ArtChoice()

    var stepProgress: Double? { steps.map { min(1, Double($0) / Double(max(stepGoal, 1))) } }

    static func placeholder(_ date: Date = Date(), id: String = "pikachu") -> CompanionEntry {
        let c = CharacterRegistry.shared.character(id)
        return CompanionEntry(date: date, character: c, mood: .happy,
                              battery: BatterySnapshot(level: 0.72, state: .unplugged, isLowPower: false),
                              steps: 6482, stepGoal: 8000, accent: Color(hex: c.accentHex))
    }
}

/// Complications can't animate and only refresh on a system budget, so the provider
/// emits a few hours of entries (mood follows the time of day) and asks to be
/// reloaded afterwards. The app also requests a reload when steps move noticeably.
struct CompanionProvider: AppIntentTimelineProvider {
    private let store = HealthQueries.isAvailable ? HKHealthStore() : nil

    func placeholder(in context: Context) -> CompanionEntry { .placeholder() }

    func snapshot(for configuration: CompanionConfiguration, in context: Context) async -> CompanionEntry {
        if context.isPreview { return .placeholder(id: configuration.pokemon?.id ?? "pikachu") }
        return await entries(configuration, from: Date(), count: 1).first ?? .placeholder()
    }

    func timeline(for configuration: CompanionConfiguration, in context: Context) async -> Timeline<CompanionEntry> {
        let now = Date()
        let list = await entries(configuration, from: now, count: 8)
        return Timeline(entries: list, policy: .after(now.addingTimeInterval(2 * 3600)))
    }

    /// watchOS shows these as ready-made choices when editing a face.
    func recommendations() -> [AppIntentRecommendation<CompanionConfiguration>] {
        let registry = CharacterRegistry.shared
        return CharacterRegistry.builtInOrder.filter(registry.contains).map(registry.character).map {
            AppIntentRecommendation(intent: CompanionConfiguration(pokemon: PokemonEntity($0)), description: $0.name)
        }
    }

    private func entries(_ config: CompanionConfiguration, from now: Date, count: Int) async -> [CompanionEntry] {
        let character = CharacterRegistry.shared.character(config.pokemon?.id ?? "pikachu")
        let goal = max(1000, config.stepGoal)
        let steps: Int? = if let store { await HealthQueries.todaySteps(store: store, now: now) } else { nil }
        let battery = liveBattery()

        return (0..<count).map { i in
            let date = now.addingTimeInterval(Double(i) * 15 * 60)
            let mood = MoodEngine.mood(for: character, MoodInputs(
                date: date, batteryLevel: battery?.level, isCharging: battery?.isCharging ?? false,
                stepProgress: steps.map { Double($0) / Double(goal) }))
            return CompanionEntry(date: date, character: character, mood: mood,
                                  battery: i == 0 ? battery : nil,   // never project a battery reading forward
                                  steps: steps, stepGoal: goal, accent: Color(hex: character.accentHex),
                                  art: ArtChoice(style: config.sprites.style, shiny: config.shiny))
        }
    }

    /// WatchKit battery reading from the extension. Returns nil where the platform
    /// doesn't report one, and the complication then hides the battery.
    private func liveBattery() -> BatterySnapshot? {
        let device = WKInterfaceDevice.current()
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        guard level >= 0 else { return nil }
        let state: BatterySnapshot.State = switch device.batteryState {
        case .charging: .charging
        case .full: .full
        case .unplugged: .unplugged
        default: .unknown
        }
        return BatterySnapshot(level: Double(level), state: state, isLowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
    }
}

// MARK: - Widgets

struct CompanionWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PokeWatchCompanion", intent: CompanionConfiguration.self,
                               provider: CompanionProvider()) { entry in
            CompanionWidgetView(entry: entry)
                .widgetURL(URL(string: "pokewatch://face"))
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("PokéWatch")
        .description("Your Pokémon, its mood, battery and steps. Tap to open PokéWatch.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct StepsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PokeWatchSteps", intent: CompanionConfiguration.self,
                               provider: CompanionProvider()) { entry in
            StepsWidgetView(entry: entry)
                .widgetURL(URL(string: "pokewatch://face"))
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("PokéWatch Steps")
        .description("Daily step progress with your Pokémon.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}
