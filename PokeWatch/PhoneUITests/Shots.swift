import XCTest

/// Screenshots of every tab in portrait and landscape, on every screen the device has
/// (the iPhone Duo reports its front and unfolded screens separately). Run by
/// Scripts/phone-shots.sh locally and .github/workflows/phone-shots.yml on the Duo;
/// the images come out of the result bundle as attachments.
@MainActor
final class Shots: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func shot(_ name: String) {
        for (n, screen) in XCUIScreen.screens.enumerated() {
            let attachment = XCTAttachment(screenshot: screen.screenshot())
            attachment.name = "\(name)-screen\(n)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func capture(_ label: String, tab: String, extra: [String] = [], search: String? = nil) {
        for (side, orientation) in [("portrait", UIDeviceOrientation.portrait), ("landscape", .landscapeLeft)] {
            XCUIDevice.shared.orientation = orientation
            let app = XCUIApplication()
            app.launchArguments = ["--tab", tab, "--pokemon", "pikachu", "--style", "gen5", "--face", "electric"] + extra
            app.launch()
            sleep(3)
            if let search, app.searchFields.firstMatch.waitForExistence(timeout: 3) {
                app.searchFields.firstMatch.tap()
                app.typeText(search)
                sleep(2)
            }
            shot("\(label)-\(side)")
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
    }

    func testCompanion() { capture("1-companion", tab: "companion") }
    func testCompanionGenOne() {
        capture("2-companion-gen1", tab: "companion", extra: ["--style", "gen1", "--pokemon", "mew", "--face", "yellow"])
    }
    func testPokedex() { capture("3-pokedex", tab: "pokedex") }
    func testPokedexSearch() { capture("4-pokedex-search", tab: "pokedex", search: "char") }
    func testFaces() { capture("5-faces", tab: "faces") }
    func testWatch() { capture("6-watch", tab: "watch") }
}
