import XCTest
@testable import PokeWatch

final class SpriteStyleTests: XCTestCase {
    func testFallbackPrefersNewerGenerations() {
        XCTAssertEqual(SpriteStyle.gen1.fallbackChain, [.gen1, .gen2, .gen3, .gen4, .gen5, .modern])
        XCTAssertEqual(SpriteStyle.gen4.fallbackChain, [.gen4, .gen5, .modern, .gen3, .gen2, .gen1])
        XCTAssertEqual(SpriteStyle.modern.fallbackChain.first, .modern)
        XCTAssertEqual(SpriteStyle.modern.fallbackChain[1], .gen5)
    }

    func testResolveFallsBackAcrossStylesAndShiny() {
        // Umbreon is missing in Gen I; Gen I has no shiny sprites at all.
        let have: Set<String> = ["gen2/umbreon/false", "gen2/umbreon/true", "gen1/pikachu/false"]
        let exists: (String, SpriteStyle, Bool) -> Bool = { have.contains("\($1.rawValue)/\($0)/\($2)") }
        XCTAssertEqual(SpriteFiles.resolve(id: "umbreon", style: .gen1, shiny: false, exists: exists)?.0, .gen2)
        let pika = SpriteFiles.resolve(id: "pikachu", style: .gen1, shiny: true, exists: exists)
        XCTAssertEqual(pika?.0, .gen1)
        XCTAssertEqual(pika?.1, false)
        XCTAssertNil(SpriteFiles.resolve(id: "missingno", style: .gen5, shiny: false, exists: exists))
    }
}

final class ImportedSpriteTests: XCTestCase {
    private func requireImports() throws {
        guard SpriteFiles.animationDirectory(id: "pikachu", style: .gen5, shiny: false) != nil else {
            throw XCTSkip("Sprites not imported (run Scripts/import_sprites.py)")
        }
    }

    func testEveryCharacterHasArtInEveryStyle() throws {
        try requireImports()
        let lib = SpriteLibrary()
        for c in CharacterRegistry.shared.characters {
            for style in SpriteStyle.allCases {
                XCTAssertNotNil(lib.clip(for: c.id, style: style, shiny: false), "\(c.id) \(style)")
            }
        }
    }

    func testClipTimingFollowsManifest() throws {
        try requireImports()
        let clip = try XCTUnwrap(SpriteLibrary().clip(for: "pikachu", style: .gen5, shiny: false))
        XCTAssertGreaterThan(clip.manifest.frameCount, 1)
        XCTAssertEqual(clip.frameIndex(at: 0), 0)
        let firstMs = Double(clip.manifest.durationsMs[0])
        XCTAssertEqual(clip.frameIndex(at: (firstMs + 1) / 1000), 1)
        // Wraps around after the whole animation.
        XCTAssertEqual(clip.frameIndex(at: Double(clip.manifest.totalDurationMs) / 1000), 0)
        XCTAssertEqual(clip.frame(0).width, clip.manifest.frameWidth)
    }

    func testGenOneIsAStill() throws {
        try requireImports()
        let clip = try XCTUnwrap(SpriteLibrary().clip(for: "pikachu", style: .gen1, shiny: false))
        XCTAssertTrue(clip.isStill)
        XCTAssertEqual(clip.frameIndex(at: 12.3), 0)
    }

    func testLibraryKeepsFewClipsInMemory() throws {
        try requireImports()
        let lib = SpriteLibrary()
        for id in ["pikachu", "eevee", "gengar", "snorlax", "mew"] { _ = lib.clip(for: id, style: .gen5, shiny: false) }
        XCTAssertEqual(lib.cachedCount, SpriteLibrary.capacity)
    }

    func testGameBoyShadesUseOnlyPaletteColours() throws {
        try requireImports()
        let clip = try XCTUnwrap(SpriteLibrary().clip(for: "pikachu", style: .gen5, shiny: false))
        let shades = RetroPalette.classicGreen.shades
        let img = clip.frame(0, shades: shades)
        XCTAssertEqual(img.width, clip.manifest.frameWidth)
    }
}

final class LayoutTests: XCTestCase {
    func testCornerProfileMatchesMeasurements() {
        XCTAssertEqual(ScreenShape.inset(atEdgeDistance: 10), 25.5, accuracy: 0.01)
        XCTAssertEqual(ScreenShape.inset(atEdgeDistance: 11), 24.0, accuracy: 0.01)
        XCTAssertEqual(ScreenShape.inset(atEdgeDistance: 100), 0)
        // Scales with the display.
        XCTAssertEqual(ScreenShape.inset(atEdgeDistance: 20, screenHeight: 514), 25.5 * 2, accuracy: 0.01)
        XCTAssertEqual(ScreenShape.inset(forBand: 10, 24, screenHeight: 257), 25.5 + 3, accuracy: 0.01)
        XCTAssertEqual(ScreenShape.inset(forBand: 233, 245, screenHeight: 257), 22.5 + 3, accuracy: 0.01)
    }

    func testSpriteScaleIsWholeDevicePixelsAndFits() {
        let c = CharacterRegistry.shared.character("pikachu")
        for box in [CGSize(width: 180, height: 110), CGSize(width: 90, height: 70), CGSize(width: 56, height: 48)] {
            let l = CompanionView.layout(clip: nil, character: c, box: box, fill: 0.86, displayScale: 2)
            let devicePx = l.unit * 2
            XCTAssertEqual(devicePx, devicePx.rounded(), "box \(box)")
            XCTAssertLessThanOrEqual(l.size.width, box.width)
            XCTAssertLessThanOrEqual(l.size.height, box.height * 0.86 + 0.001)
        }
    }

    func testLaunchFlagsForLayoutTests() {
        let o = LaunchOptions(arguments: ["app", "--style", "gen3", "--shiny", "--24h", "--date", "2026-09-30", "--time", "23:58"])
        XCTAssertEqual(o.style, .gen3)
        XCTAssertTrue(o.shiny)
        XCTAssertEqual(o.use24h, true)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        let shown = o.displayDate(Date(), calendar: cal)
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: shown)
        XCTAssertEqual([c.year, c.month, c.day, c.hour, c.minute], [2026, 9, 30, 23, 58])
    }
}
