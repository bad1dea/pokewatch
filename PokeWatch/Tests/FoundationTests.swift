import XCTest
@testable import PokeWatch

final class ClockFormatterTests: XCTestCase {
    var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()

    func testTwelveAndTwentyFourHour() {
        let d = cal.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 21, minute: 5, second: 9))!
        let p12 = ClockFormatter.parts(for: d, use24h: false, calendar: cal)
        XCTAssertEqual(p12.hhmm, "9:05"); XCTAssertEqual(p12.period, "PM"); XCTAssertEqual(p12.second, "09")
        let p24 = ClockFormatter.parts(for: d, use24h: true, calendar: cal)
        XCTAssertEqual(p24.hhmm, "21:05"); XCTAssertNil(p24.period)
    }

    func testMidnightAndNoon() {
        let midnight = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 0, minute: 0))!
        XCTAssertEqual(ClockFormatter.parts(for: midnight, use24h: false, calendar: cal).hhmm, "12:00")
        XCTAssertEqual(ClockFormatter.parts(for: midnight, use24h: true, calendar: cal).hhmm, "00:00")
        let noon = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12, minute: 0))!
        XCTAssertEqual(ClockFormatter.parts(for: noon, use24h: false, calendar: cal).period, "PM")
    }
}

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testPersistsAcrossInstances() {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let a = SettingsStore(defaults: defaults)
        a.characterID = "gengar"
        a.faceStyle = .analog
        a.accent = .ghost
        a.stepGoal = 12000
        a.showSeconds = false
        a.intensity = .lively

        let b = SettingsStore(defaults: defaults)
        XCTAssertEqual(b.characterID, "gengar")
        XCTAssertEqual(b.faceStyle, .analog)
        XCTAssertEqual(b.accent, .ghost)
        XCTAssertEqual(b.stepGoal, 12000)
        XCTAssertFalse(b.showSeconds)
        XCTAssertEqual(b.intensity, .lively)

        b.resetToDefaults()
        XCTAssertEqual(SettingsStore(defaults: defaults).characterID, "pikachu")
    }

    func testStepGoalIsClamped() {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(5, forKey: SettingsStore.Key.stepGoal.name)
        XCTAssertEqual(SettingsStore(defaults: defaults).stepGoal, SettingsStore.stepGoalRange.lowerBound)
    }
}

final class MiscTests: XCTestCase {
    func testLaunchOptionsParse() {
        let o = LaunchOptions(arguments: ["app", "--demo", "--face", "pokedex", "--pokemon", "mew", "--dimmed", "--time", "10:09"])
        XCTAssertTrue(o.demo); XCTAssertTrue(o.forceDimmed)
        XCTAssertEqual(o.face, .pokedex); XCTAssertEqual(o.pokemon, "mew")
        XCTAssertEqual(o.frozenTime?.hour, 10); XCTAssertEqual(o.frozenTime?.minute, 9)
    }

    func testAnalogCompanionAvoidsHands() {
        func dist(_ a: Double, _ b: Double) -> Double { let d = abs(a - b).truncatingRemainder(dividingBy: 360); return min(d, 360 - d) }
        for h in stride(from: 0.0, to: 360, by: 17) {
            for m in stride(from: 0.0, to: 360, by: 23) {
                let a = AnalogFace.companionAngle(hour: h, minute: m)
                XCTAssertGreaterThanOrEqual(min(dist(a, h), dist(a, m)), 60, "h=\(h) m=\(m) → \(a)")
            }
        }
    }

    func testPixelFontGlyphsAreWellFormed() {
        for (ch, g) in PixelFont.glyphs {
            XCTAssertEqual(g.count, PixelFont.height, "\(ch)")
            XCTAssertEqual(Set(g.map(\.count)).count, 1, "\(ch)")
        }
        XCTAssertEqual(PixelFont.width(of: "10:09"), 25)
    }

    func testAccentAndPaletteColoursParse() {
        for a in AccentChoice.allCases { XCTAssertNotNil(RGB(hex: a.hex)) }
        for p in RetroPalette.allCases { XCTAssertEqual(p.shades.count, 4) }
    }

    func testStepFormatting() {
        XCTAssertEqual(12_400.compactSteps, "12.4k")
    }
}
