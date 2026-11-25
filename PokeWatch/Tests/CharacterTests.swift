import XCTest
@testable import PokeWatch

final class CharacterRegistryTests: XCTestCase {
    func testWithoutImportsTheTenPixelArtCharactersRemainInDexOrder() {
        let registry = CharacterRegistry(bundles: [.main], extraDirectories: [], catalog: [])
        XCTAssertEqual(registry.characters.map(\.dexNumber), [1, 4, 7, 25, 54, 94, 133, 143, 151, 197])
        XCTAssertTrue(registry.rejected.isEmpty, "Rejected: \(registry.rejected)")
        // Hand-written files without pixel art need imported art to be listed.
        let all = CharacterRegistry(bundles: [.main], extraDirectories: [], catalog: [], hasImportedArt: { _ in true })
        XCTAssertEqual(Set(all.characters.map(\.id)), Set(CharacterRegistry.builtInOrder))
    }

    func testCatalogStylesAreEraAccurate() throws {
        let registry = CharacterRegistry.shared
        guard registry.entry("pikachu") != nil else { throw XCTSkip("Sprites not imported") }
        XCTAssertGreaterThan(registry.characters.count, 1000)
        let gen1 = registry.available(in: .gen1)
        XCTAssertEqual(gen1.count, 151)
        XCTAssertTrue(gen1.allSatisfy { $0.dexNumber <= 151 })
        XCTAssertFalse(registry.isAvailable("lucario", in: .gen1))
        XCTAssertFalse(registry.isAvailable("lucario", in: .gen3))
        XCTAssertTrue(registry.isAvailable("lucario", in: .gen4))
        XCTAssertNil(SpriteLibrary().clip(for: "lucario", style: .gen1, shiny: false), "no borrowing between styles")
        for style in SpriteStyle.allCases {
            XCTAssertTrue(registry.available(in: style).allSatisfy { $0.dexNumber <= style.lastDex }, "\(style)")
        }
        // Hand-tuned personalities override the generated ones.
        XCTAssertEqual(registry.character("snorlax").personality.sleepsWhenIdle, true)
        XCTAssertEqual(registry.character("gengar").personality.nightOwl, true)
    }

    func testGeneratedCharactersFollowTheirType() {
        let e = CatalogEntry(dex: 135, id: "jolteon", name: "Jolteon", genus: "Lightning", types: ["electric"],
                             generation: 1, evolvesFrom: 133, legendary: false, mythical: false, styles: ["gen1": ["normal"]])
        let c = CharacterDefinition(catalog: e)
        XCTAssertEqual(c.element, .spark)
        XCTAssertEqual(c.category, "Lightning")
        XCTAssertEqual(c.type, "Electric")
        XCTAssertTrue(c.personality.stepLover)
        XCTAssertNoThrow(try c.validate())
        XCTAssertFalse(c.hasPixelArt)
    }

    func testEveryCharacterValidatesAndHasDistinctPersonality() throws {
        let chars = CharacterRegistry(bundles: [.main], extraDirectories: []).characters
        for c in chars {
            XCTAssertNoThrow(try c.validate(), c.id)
            guard let rows = c.sprite else { continue }
            XCTAssertGreaterThan(c.width, 10, c.id)
            XCTAssertGreaterThan(c.height, 10, c.id)
            XCTAssertEqual(Set(rows.map(\.count)).count, 1, "\(c.id) rows must share a width")
        }
        // The hand-tuned companions each move differently (generated ones vary by type and seed).
        let tuned = chars.filter { CharacterRegistry.builtInOrder.contains($0.id) }
        let signatures = Set(tuned.map { "\($0.personality.idleStyle)-\($0.personality.bobSpeed)-\($0.element)" })
        XCTAssertEqual(signatures.count, tuned.count, "Each hand-tuned Pokémon should move differently")
    }

    func testRejectsUnknownPaletteKey() {
        let json = """
        {"id":"bad","name":"Bad","dexNumber":1,"category":"x","type":"x","entry":"x","element":"spark",
         "accentHex":"#FFFFFF","palette":{"K":"#000000"},"eyes":{"keys":["K"],"fill":"K","line":"K"},"earRows":0,
         "personality":{"idleStyle":"bounce","energy":1,"sleepiness":0,"bobSpeed":1,"bobAmplitude":1,"blinkInterval":3,
           "hopHeight":1,"nightOwl":false,"sleepsWhenIdle":false,"stepLover":false},
         "lines":{"idle":"","happy":"","excited":"","celebrate":"","tired":"","charging":"","sleep":"","wake":""},
         "sprite":["KZ"]}
        """
        XCTAssertThrowsError(try CharacterRegistry.decode(Data(json.utf8)))
    }

    func testUnknownEnumValuesFallBack() throws {
        let url = Bundle.main.url(forResource: "pikachu.pokemon", withExtension: "json")!
        var text = try String(contentsOf: url, encoding: .utf8)
        text = text.replacingOccurrences(of: "\"bounce\"", with: "\"moonwalk\"")
            .replacingOccurrences(of: "\"spark\"", with: "\"glitter\"")
        let def = try CharacterRegistry.decode(Data(text.utf8))
        XCTAssertEqual(def.personality.idleStyle, .bounce)
        XCTAssertEqual(def.element, .sparkle)
    }

    func testDropInCharacterDirectoryAddsAndOverrides() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let src = Bundle.main.url(forResource: "eevee.pokemon", withExtension: "json")!
        var text = try String(contentsOf: src, encoding: .utf8)
        text = text.replacingOccurrences(of: "\"id\": \"eevee\"", with: "\"id\": \"shinyeevee\"")
            .replacingOccurrences(of: "\"name\": \"Eevee\"", with: "\"name\": \"Shiny Eevee\"")
        try text.write(to: dir.appendingPathComponent("shinyeevee.pokemon.json"), atomically: true, encoding: .utf8)

        let base = CharacterRegistry(bundles: [.main], extraDirectories: []).characters.count
        let registry = CharacterRegistry(bundles: [.main], extraDirectories: [dir])
        XCTAssertEqual(registry.characters.count, base + 1)
        XCTAssertEqual(registry.character("shinyeevee").name, "Shiny Eevee")
        XCTAssertTrue(registry.contains("shinyeevee"))
    }

    func testUnknownIDFallsBackToFirstCharacter() throws {
        let registry = CharacterRegistry(bundles: [.main], extraDirectories: [])
        XCTAssertEqual(registry.character("missingno").id, registry.characters.first?.id)
        let i = try XCTUnwrap(registry.characters.firstIndex { $0.id == "pikachu" })
        XCTAssertEqual(registry.neighbour(of: "pikachu", offset: -1).id, registry.characters[i - 1].id)
    }
}

final class SpriteRasterizerTests: XCTestCase {
    let pikachu = CharacterRegistry.shared.character("pikachu")

    func testImageMatchesGridSize() throws {
        let img = try XCTUnwrap(SpriteRasterizer.rasterize(pikachu, expression: .open, earTwitch: false, tint: .natural))
        XCTAssertEqual(img.width, pikachu.width)
        XCTAssertEqual(img.height, pikachu.height)
    }

    func testClosedEyesRemoveEyeKeysAndLeaveALine() {
        let open = SpriteRasterizer.grid(for: pikachu, expression: .open, earTwitch: false)
        let closed = SpriteRasterizer.grid(for: pikachu, expression: .closed, earTwitch: false)
        let eyeKeys = Set(pikachu.eyes!.keys)
        let openEyes = open.joined().filter { $0.map(eyeKeys.contains) ?? false }.count
        let closedEyes = closed.joined().filter { $0.map(eyeKeys.contains) ?? false }.count
        XCTAssertGreaterThan(openEyes, 0)
        XCTAssertEqual(closedEyes, 0)
        XCTAssertNotEqual(open, closed)
    }

    func testAllExpressionsDifferForEveryCharacter() {
        for c in CharacterRegistry.shared.characters where c.hasPixelArt {
            let grids = SpriteExpression.allCases.map { SpriteRasterizer.grid(for: c, expression: $0, earTwitch: false) }
            XCTAssertNotEqual(grids[0], grids[1], "\(c.id) blink must be visible")
            XCTAssertNotEqual(grids[1], grids[2], "\(c.id) happy must differ from closed")
        }
    }

    func testEarTwitchOnlyTouchesEarRows() {
        let base = SpriteRasterizer.grid(for: pikachu, expression: .open, earTwitch: false)
        let twitch = SpriteRasterizer.grid(for: pikachu, expression: .open, earTwitch: true)
        let rows = pikachu.earRows ?? 0
        XCTAssertNotEqual(Array(base.prefix(rows)), Array(twitch.prefix(rows)))
        XCTAssertEqual(Array(base.dropFirst(rows)), Array(twitch.dropFirst(rows)))
    }

    func testCacheReusesImages() {
        let r = SpriteRasterizer()
        let a = r.image(for: pikachu, expression: .happy)
        let b = r.image(for: pikachu, expression: .happy)
        XCTAssertTrue(a === b)
        XCTAssertEqual(r.cachedCount, 1)
        _ = r.image(for: pikachu, expression: .happy, tint: .dimmed(40))
        XCTAssertEqual(r.cachedCount, 2)
    }

    func testDimmedTintReducesBrightness() {
        let y = SpriteRasterizer.color(for: "Y", in: pikachu, tint: .natural)!
        let d = SpriteRasterizer.color(for: "Y", in: pikachu, tint: .dimmed(40))!
        XCTAssertLessThan(d.luminance, y.luminance * 0.5)
    }

    func testShadesMapToPalette() {
        let shades = RetroPalette.classicGreen.shades
        for key in pikachu.palette!.keys {
            let c = SpriteRasterizer.color(for: key, in: pikachu, tint: .shades(shades))!
            XCTAssertTrue(shades.contains(c))
        }
    }
}
