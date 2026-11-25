import XCTest
@testable import PokeWatch

final class SpritePackTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func testRoundTrip() throws {
        let a = dir.appendingPathComponent("a.bin"), b = dir.appendingPathComponent("b.json")
        try Data((0..<5000).map { UInt8($0 % 251) }).write(to: a)
        try Data("{\"x\":1}".utf8).write(to: b)
        let archive = dir.appendingPathComponent("p.pwpk")
        try SpritePackArchive.write([("modern/pikachu/shiny/sheet.png", a), ("modern/pikachu/shiny/manifest.json", b)], to: archive)
        let out = dir.appendingPathComponent("out")
        XCTAssertEqual(try SpritePackArchive.unpack(archive, into: out), 2)
        XCTAssertEqual(try Data(contentsOf: out.appendingPathComponent("modern/pikachu/shiny/sheet.png")), try Data(contentsOf: a))
        XCTAssertEqual(try Data(contentsOf: out.appendingPathComponent("modern/pikachu/shiny/manifest.json")), try Data(contentsOf: b))
    }

    func testRejectsPathsOutsideTheFolder() throws {
        let a = dir.appendingPathComponent("a.bin")
        try Data([1, 2, 3]).write(to: a)
        let archive = dir.appendingPathComponent("evil.pwpk")
        try SpritePackArchive.write([("../../escape.bin", a)], to: archive)
        XCTAssertThrowsError(try SpritePackArchive.unpack(archive, into: dir.appendingPathComponent("out")))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.deletingLastPathComponent().appendingPathComponent("escape.bin").path))
    }

    func testRejectsGarbage() throws {
        let junk = dir.appendingPathComponent("junk.pwpk")
        try Data("not a pack at all".utf8).write(to: junk)
        XCTAssertThrowsError(try SpritePackArchive.unpack(junk, into: dir))
    }

    func testPackContents() {
        XCTAssertTrue(SpritePackKind.shiny.includes(style: "gen3", variant: "shiny"))
        XCTAssertFalse(SpritePackKind.shiny.includes(style: "gen3", variant: "normal"))
        XCTAssertTrue(SpritePackKind.fullModern.includes(style: "modern", variant: "normal"))
        XCTAssertFalse(SpritePackKind.fullModern.includes(style: "gen5", variant: "normal"))
    }

    func testInstalledPackIsSearchedBeforeTheBundle() throws {
        let root = dir.appendingPathComponent("pack")
        let sprite = root.appendingPathComponent("gen5/pikachu/shiny")
        try FileManager.default.createDirectory(at: sprite, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: sprite.appendingPathComponent("manifest.json"))
        let saved = SpriteFiles.extraRoots
        defer { SpriteFiles.extraRoots = saved }
        SpriteFiles.extraRoots = [root]
        XCTAssertEqual(SpriteFiles.animationDirectory(id: "pikachu", style: .gen5, shiny: true)?.standardizedFileURL,
                       sprite.standardizedFileURL)
    }
}

@MainActor
final class SettingsSyncTests: XCTestCase {
    private func store() -> (SettingsStore, UserDefaults, String) {
        let suite = "sync.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        return (SettingsStore(defaults: d), d, suite)
    }

    func testNewerRemoteSettingsWinAndOlderAreIgnored() {
        let (phone, pd, ps) = store(), (watch, wd, ws) = store()
        defer { pd.removePersistentDomain(forName: ps); wd.removePersistentDomain(forName: ws) }

        phone.characterID = "gengar"
        phone.spriteStyle = .gen3
        XCTAssertTrue(watch.apply(syncPayload: phone.syncPayload))
        XCTAssertEqual(watch.characterID, "gengar")
        XCTAssertEqual(watch.spriteStyle, .gen3)
        // Applying again (same timestamp) does nothing; an older payload is ignored.
        XCTAssertFalse(watch.apply(syncPayload: phone.syncPayload))
        let old = phone.syncPayload
        watch.characterID = "mew"
        XCTAssertFalse(watch.apply(syncPayload: old))
        XCTAssertEqual(watch.characterID, "mew")
    }

    func testRemoteChangesDontEchoBack() {
        let (phone, pd, ps) = store(), (watch, wd, ws) = store()
        defer { pd.removePersistentDomain(forName: ps); wd.removePersistentDomain(forName: ws) }
        var echoes = 0
        watch.onLocalChange = { echoes += 1 }
        phone.accent = .ghost
        watch.apply(syncPayload: phone.syncPayload)
        XCTAssertEqual(watch.accent, .ghost)
        XCTAssertEqual(echoes, 0)
        watch.accent = .leaf
        XCTAssertEqual(echoes, 1)
    }
}
