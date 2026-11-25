import XCTest
@testable import PokeWatch

final class CharacterRegistryTests: XCTestCase {
    func testLoadsAllTenBuiltInCharactersInOrder() {
        let registry = CharacterRegistry(bundles: [.main], extraDirectories: [])
        XCTAssertEqual(registry.characters.map(\.id), CharacterRegistry.builtInOrder)
        XCTAssertTrue(registry.rejected.isEmpty, "Rejected: \(registry.rejected)")
    }

    func testEveryCharacterValidatesAndHasDistinctPersonality() throws {
        let chars = CharacterRegistry(bundles: [.main], extraDirectories: []).characters
        for c in chars {
            XCTAssertNoThrow(try c.validate(), c.id)
            XCTAssertGreaterThan(c.width, 10, c.id)
            XCTAssertGreaterThan(c.height, 10, c.id)
            XCTAssertEqual(Set(c.sprite.map(\.count)).count, 1, "\(c.id) rows must share a width")
        }
        let signatures = Set(chars.map { "\($0.personality.idleStyle)-\($0.personality.bobSpeed)-\($0.element)" })
        XCTAssertEqual(signatures.count, chars.count, "Each Pokémon should move differently")
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

        let registry = CharacterRegistry(bundles: [.main], extraDirectories: [dir])
        XCTAssertEqual(registry.characters.count, 11)
        XCTAssertEqual(registry.character("shinyeevee").name, "Shiny Eevee")
        XCTAssertEqual(registry.characters.last?.id, "shinyeevee")
    }

    func testUnknownIDFallsBackToFirstCharacter() {
        let registry = CharacterRegistry(bundles: [.main], extraDirectories: [])
        XCTAssertEqual(registry.character("missingno").id, "pikachu")
        XCTAssertEqual(registry.neighbour(of: "pikachu", offset: -1).id, "psyduck")
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
        let eyeKeys = Set(pikachu.eyes.keys)
        let openEyes = open.joined().filter { $0.map(eyeKeys.contains) ?? false }.count
        let closedEyes = closed.joined().filter { $0.map(eyeKeys.contains) ?? false }.count
        XCTAssertGreaterThan(openEyes, 0)
        XCTAssertEqual(closedEyes, 0)
        XCTAssertNotEqual(open, closed)
    }

    func testAllExpressionsDifferForEveryCharacter() {
        for c in CharacterRegistry.shared.characters {
            let grids = SpriteExpression.allCases.map { SpriteRasterizer.grid(for: c, expression: $0, earTwitch: false) }
            XCTAssertNotEqual(grids[0], grids[1], "\(c.id) blink must be visible")
            XCTAssertNotEqual(grids[1], grids[2], "\(c.id) happy must differ from closed")
        }
    }

    func testEarTwitchOnlyTouchesEarRows() {
        let base = SpriteRasterizer.grid(for: pikachu, expression: .open, earTwitch: false)
        let twitch = SpriteRasterizer.grid(for: pikachu, expression: .open, earTwitch: true)
        XCTAssertNotEqual(Array(base.prefix(pikachu.earRows)), Array(twitch.prefix(pikachu.earRows)))
        XCTAssertEqual(Array(base.dropFirst(pikachu.earRows)), Array(twitch.dropFirst(pikachu.earRows)))
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
        for key in pikachu.palette.keys {
            let c = SpriteRasterizer.color(for: key, in: pikachu, tint: .shades(shades))!
            XCTAssertTrue(shades.contains(c))
        }
    }
}
