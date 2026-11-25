import Foundation

/// One Pokémon from the imported Pokédex catalog (`catalog.json`, written by
/// `Scripts/import_sprites.py`): names, category, types, generation and which sprite
/// styles exist for it.
struct CatalogEntry: Codable, Hashable, Sendable {
    let dex: Int
    let id: String
    let name: String
    let genus: String
    let types: [String]
    let generation: Int
    let evolvesFrom: Int?
    let legendary: Bool
    let mythical: Bool
    /// style raw value → variants ("normal", "shiny") available.
    let styles: [String: [String]]

    func has(_ style: SpriteStyle, shiny: Bool = false) -> Bool {
        styles[style.rawValue]?.contains(shiny ? "shiny" : "normal") ?? false
    }
}

enum PokedexCatalog {
    /// Looks for `catalog.json` in the imported sprite folders of the given bundles.
    static func load(bundles: [Bundle]) -> [CatalogEntry] {
        for bundle in bundles {
            for folder in ["ImportedSprites", "ImportedStills"] {
                guard let url = bundle.resourceURL?.appendingPathComponent("\(folder)/catalog.json"),
                      let data = try? Data(contentsOf: url),
                      let entries = try? JSONDecoder().decode([CatalogEntry].self, from: data) else { continue }
                return entries
            }
        }
        return []
    }
}

extension CharacterDefinition {
    /// A companion for any catalog Pokémon without a hand-written character file.
    /// Personality, particles and motion follow its primary type; seeds vary the details
    /// so two Pokémon of the same type still move differently.
    init(catalog e: CatalogEntry) {
        let primary = e.types.first ?? "normal"
        let traits = TypeTraits.for(primary)
        let seed = Double(e.dex % 97) / 97
        let display = e.name
        self.init(
            id: e.id, name: display, dexNumber: e.dex, category: e.genus.isEmpty ? "Pokémon" : e.genus,
            type: e.types.map { $0.capitalized }.joined(separator: "/"),
            entry: "\(e.genus.isEmpty ? display : e.genus) Pokémon, first seen in Generation \(e.generation).",
            element: traits.element, accentHex: traits.accent, palette: nil, eyes: nil, earRows: nil,
            personality: Personality(
                idleStyle: traits.idle,
                energy: min(1, traits.energy + (seed - 0.5) * 0.3),
                sleepiness: min(1, max(0, traits.sleepiness + (0.5 - seed) * 0.3)),
                bobSpeed: traits.speed * (0.85 + seed * 0.3),
                bobAmplitude: 0.6 + seed * 0.5,
                blinkInterval: 3 + seed * 3,
                hopHeight: e.legendary || e.mythical ? 1.5 : 2 + seed * 2,
                nightOwl: primary == "ghost" || primary == "dark",
                sleepsWhenIdle: traits.sleepiness >= 0.7,
                stepLover: ["fighting", "electric", "fire"].contains(primary)),
            lines: Lines(idle: "\(display)?", happy: "\(display)!", excited: "\(display)!!",
                         celebrate: display.uppercased() + "!", tired: "\(display.lowercased())...",
                         charging: "...", sleep: "zzz", wake: "\(display)?"),
            sprite: nil, order: nil)
    }
}

private struct TypeTraits {
    let element: ParticleElement
    let idle: IdleStyle
    let accent: String
    let energy: Double
    let sleepiness: Double
    let speed: Double

    static func `for`(_ type: String) -> TypeTraits {
        switch type {
        case "electric": TypeTraits(element: .spark, idle: .bounce, accent: "#FFE100", energy: 0.9, sleepiness: 0.3, speed: 2.2)
        case "fire": TypeTraits(element: .ember, idle: .waddle, accent: "#FF8A3D", energy: 0.8, sleepiness: 0.3, speed: 1.8)
        case "water": TypeTraits(element: .bubble, idle: .bounce, accent: "#5CC8F0", energy: 0.6, sleepiness: 0.4, speed: 1.5)
        case "ice": TypeTraits(element: .bubble, idle: .sway, accent: "#9FE6F2", energy: 0.5, sleepiness: 0.4, speed: 1.1)
        case "grass": TypeTraits(element: .leaf, idle: .sway, accent: "#7CD67A", energy: 0.5, sleepiness: 0.5, speed: 1.2)
        case "bug": TypeTraits(element: .leaf, idle: .wobble, accent: "#B5D44A", energy: 0.6, sleepiness: 0.4, speed: 1.6)
        case "poison": TypeTraits(element: .wisp, idle: .wobble, accent: "#B97FD9", energy: 0.5, sleepiness: 0.4, speed: 1.2)
        case "ghost": TypeTraits(element: .wisp, idle: .float, accent: "#A77BE8", energy: 0.6, sleepiness: 0.2, speed: 1.0)
        case "dark": TypeTraits(element: .moon, idle: .sway, accent: "#FFD34A", energy: 0.5, sleepiness: 0.3, speed: 1.0)
        case "psychic": TypeTraits(element: .psychic, idle: .float, accent: "#FF9ACB", energy: 0.6, sleepiness: 0.3, speed: 1.1)
        case "fairy": TypeTraits(element: .sparkle, idle: .bounce, accent: "#FFB4D6", energy: 0.6, sleepiness: 0.5, speed: 1.4)
        case "dragon": TypeTraits(element: .sparkle, idle: .breathe, accent: "#8C7CF0", energy: 0.7, sleepiness: 0.3, speed: 1.0)
        case "flying": TypeTraits(element: .sparkle, idle: .float, accent: "#A9C4F5", energy: 0.7, sleepiness: 0.3, speed: 1.4)
        case "fighting": TypeTraits(element: .sparkle, idle: .sway, accent: "#E8774A", energy: 0.9, sleepiness: 0.2, speed: 1.6)
        case "rock", "ground": TypeTraits(element: .sparkle, idle: .breathe, accent: "#D8B46A", energy: 0.4, sleepiness: 0.5, speed: 0.8)
        case "steel": TypeTraits(element: .sparkle, idle: .breathe, accent: "#B8C4D0", energy: 0.4, sleepiness: 0.4, speed: 0.8)
        default: TypeTraits(element: .sparkle, idle: .bounce, accent: "#F2E4BF", energy: 0.6, sleepiness: 0.5, speed: 1.3)
        }
    }
}
