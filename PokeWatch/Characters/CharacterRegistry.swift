import Foundation

/// Discovers every `*.pokemon.json` character file. Sources, in override order:
/// 1. files bundled in the app (and widget) bundle,
/// 2. files placed in the app's `Documents/Characters` directory.
/// A later file with the same `id` replaces an earlier one, so characters can be
/// added or restyled without rebuilding the app.
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

    /// - Parameter hasImportedArt: whether imported sprites exist for an id. A character is listed
    ///   when it has imported art or fallback pixel art.
    init(bundles: [Bundle] = [.main], extraDirectories: [URL] = CharacterRegistry.userDirectories,
         hasImportedArt: (String) -> Bool = CharacterRegistry.importedArtExists) {
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
        self.rejected = rejected
    }

    static func decode(_ data: Data) throws -> CharacterDefinition {
        let def = try JSONDecoder().decode(CharacterDefinition.self, from: data)
        try def.validate()
        return def
    }

    /// Any imported animation or still, in any style, in the main bundle.
    static func importedArtExists(_ id: String) -> Bool {
        SpriteStyle.allCases.contains {
            SpriteFiles.animationDirectory(id: id, style: $0, shiny: false) != nil
                || SpriteFiles.stillURL(id: id, style: $0, shiny: false) != nil
        }
    }

    static var userDirectories: [URL] {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return [] }
        return [docs.appendingPathComponent("Characters", isDirectory: true)]
    }

    private static func sortOrder(_ a: CharacterDefinition, _ b: CharacterDefinition) -> Bool {
        func rank(_ c: CharacterDefinition) -> Int {
            if let o = c.order { return o }
            if let i = builtInOrder.firstIndex(of: c.id) { return i }
            return 1000 + c.dexNumber
        }
        let (ra, rb) = (rank(a), rank(b))
        return ra == rb ? a.name < b.name : ra < rb
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
