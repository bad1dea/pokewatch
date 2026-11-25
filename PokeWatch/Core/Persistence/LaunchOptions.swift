import Foundation

/// Command-line switches for simulator automation (screenshots, demos). Ignored in normal use.
///
///   --demo              fake battery + activity data (the simulator has neither)
///   --face <style>      electric | yellow | minimal | sleeping | pokedex | analog
///   --pokemon <id>      e.g. pikachu, gengar
///   --accent <name>     electric | ember | aqua | …
///   --palette <name>    classicGreen | monochrome | pikaYellow
///   --dimmed            render the Always-On presentation (simulation only)
///   --mood <mood>       force a mood (sleeping, happy, celebrating, tired, …)
///   --time HH:MM        freeze the displayed clock
///   --settings          open customization on launch
///   --browser           open the full Pokémon grid on launch
///   --style <style>     gen1 | gen2 | gen3 | gen4 | gen5 | modern
///   --shiny             shiny sprites
///   --24h / --12h       clock format
///   --date YYYY-MM-DD   freeze the displayed date (with --time, for layout tests)
struct LaunchOptions: Sendable {
    var demo = false
    var face: FaceStyle?
    var pokemon: String?
    var accent: AccentChoice?
    var palette: RetroPalette?
    var forceDimmed = false
    var mood: Mood?
    var frozenTime: DateComponents?
    var openSettings = false
    var openBrowser = false
    /// iPhone app: tab to open (companion, pokedex, faces, watch).
    var phoneTab: String?
    var style: SpriteStyle?
    var shiny = false
    var use24h: Bool?
    var frozenDate: DateComponents?

    static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    init(arguments: [String] = []) {
        var it = arguments.dropFirst().makeIterator()
        while let a = it.next() {
            switch a {
            case "--demo": demo = true
            case "--dimmed": forceDimmed = true
            case "--settings": openSettings = true
            case "--browser": openBrowser = true
            case "--tab": phoneTab = it.next()
            case "--shiny": shiny = true
            case "--24h": use24h = true
            case "--12h": use24h = false
            case "--style": style = it.next().flatMap(SpriteStyle.init(rawValue:))
            case "--date":
                if let v = it.next() {
                    let p = v.split(separator: "-").compactMap { Int($0) }
                    if p.count == 3 { frozenDate = DateComponents(year: p[0], month: p[1], day: p[2]) }
                }
            case "--face": face = it.next().flatMap(FaceStyle.init(rawValue:))
            case "--pokemon": pokemon = it.next()
            case "--accent": accent = it.next().flatMap(AccentChoice.init(rawValue:))
            case "--palette": palette = it.next().flatMap(RetroPalette.init(rawValue:))
            case "--mood": mood = it.next().flatMap(Mood.init(rawValue:))
            case "--time":
                if let v = it.next() {
                    let parts = v.split(separator: ":").compactMap { Int($0) }
                    if parts.count >= 2 {
                        frozenTime = DateComponents(hour: parts[0], minute: parts[1], second: parts.count > 2 ? parts[2] : 30)
                    }
                }
            default: break
            }
        }
    }

    func displayDate(_ real: Date, calendar: Calendar = .current) -> Date {
        guard frozenTime != nil || frozenDate != nil else { return real }
        var c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: real)
        if let d = frozenDate { c.year = d.year; c.month = d.month; c.day = d.day }
        if let f = frozenTime { c.hour = f.hour; c.minute = f.minute }
        // Keep seconds live so animation and the second hand still move.
        c.second = calendar.component(.second, from: real)
        return calendar.date(from: c) ?? real
    }
}
