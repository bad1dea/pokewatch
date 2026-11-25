import Foundation

/// All companions. Sources, in override order:
/// 1. the imported Pokédex catalog (every Pokémon with imported sprites, generated personality),
/// 2. hand-written `*.pokemon.json` files bundled in the app (tuned personality, fallback pixel art),
/// 3. files placed in the app's `Documents/Characters` directory.
/// A later source with the same `id` replaces an earlier one.
final class CharacterRegistry: @unchecked Sendable {
    static let shared = CharacterRegistry()

    static let fileSuffix = ".pokemon.json"
    static let builtInOrder = ["pikachu", "eevee", "gengar", "snorlax", "charmander",
                               "squirtle", "bulbasaur", "mew", "umbreon", "psyduck",
                               "charizard", "mewtwo", "lucario", "dragonite", "jigglypuff", "espeon"]

    let characters: [CharacterDefinition]
    /// Files that failed to decode or validate, for diagnostics.
    let rejected: [String]
    private let byID: [String: CharacterDefinition]
    private let catalog: [String: CatalogEntry]

    /// - Parameter hasImportedArt: whether imported sprites exist for an id. A character is listed
    ///   when it has imported art or fallback pixel art.
    init(bundles: [Bundle] = [.main], extraDirectories: [URL] = CharacterRegistry.userDirectories,
         catalog catalogEntries: [CatalogEntry]? = nil,
         hasImportedArt: ((String) -> Bool)? = nil) {
        let entries = catalogEntries ?? PokedexCatalog.load(bundles: bundles + SpriteFiles.stillBundles)
        let catalog = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let hasImportedArt = hasImportedArt ?? { catalog[$0] != nil }
        var urls: [URL] = []
        for bundle in bundles {
            urls += bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
            urls += bundle.urls(forResourcesWithExtension: "json", subdirectory: "Sprites") ?? []
        }
        let fm = FileManager.default
        for dir in extraDirectories {
            let items = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            urls += items.sorted { $0.lastPathComponent < $1.lastPathComponent }
        }

        var found: [String: CharacterDefinition] = [:]
        for e in entries { found[e.id] = CharacterDefinition(catalog: e) }
        var rejected: [String] = []
        for url in urls where url.lastPathComponent.hasSuffix(Self.fileSuffix) {
            do {
                let def = try Self.decode(try Data(contentsOf: url))
                guard def.hasPixelArt || hasImportedArt(def.id) else { continue }
                found[def.id] = def
            } catch {
                rejected.append(url.lastPathComponent)
            }
        }
        if found.isEmpty { found[CharacterDefinition.placeholder.id] = .placeholder }

        characters = found.values.sorted(by: Self.sortOrder)
        byID = found
        self.catalog = catalog
        self.rejected = rejected
    }

    static func decode(_ data: Data) throws -> CharacterDefinition {
        let def = try JSONDecoder().decode(CharacterDefinition.self, from: data)
        try def.validate()
        return def
    }

    static var userDirectories: [URL] {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return [] }
        return [docs.appendingPathComponent("Characters", isDirectory: true)]
    }

    /// National dex order; `order` in a character file overrides it.
    private static func sortOrder(_ a: CharacterDefinition, _ b: CharacterDefinition) -> Bool {
        let (ra, rb) = (a.order ?? a.dexNumber, b.order ?? b.dexNumber)
        return ra == rb ? a.name < b.name : ra < rb
    }

    func entry(_ id: String) -> CatalogEntry? { catalog[id] }

    /// Generation the Pokémon debuted in (from the catalog, else derived from the dex number).
    func generation(of c: CharacterDefinition) -> Int {
        if let g = catalog[c.id]?.generation { return g }
        let tops = [151, 251, 386, 493, 649, 721, 809, 905, 1025]
        return (tops.firstIndex { c.dexNumber <= $0 } ?? 8) + 1
    }

    /// Era-accurate: only Pokémon with a native sprite in `style`. Without imported sprites,
    /// every character with fallback pixel art is available.
    func isAvailable(_ id: String, in style: SpriteStyle) -> Bool {
        if catalog.isEmpty { return byID[id]?.hasPixelArt ?? false }
        return catalog[id]?.has(style) ?? false
    }

    func available(in style: SpriteStyle) -> [CharacterDefinition] {
        characters.filter { isAvailable($0.id, in: style) }
    }

    func character(_ id: String) -> CharacterDefinition {
        byID[id] ?? characters.first ?? .placeholder
    }

    func contains(_ id: String) -> Bool { byID[id] != nil }

    func neighbour(of id: String, offset: Int) -> CharacterDefinition {
        guard let i = characters.firstIndex(where: { $0.id == id }) else { return character(id) }
        let n = characters.count
        return characters[((i + offset) % n + n) % n]
    }
}
