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

    static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    init(arguments: [String] = []) {
        var it = arguments.dropFirst().makeIterator()
        while let a = it.next() {
            switch a {
            case "--demo": demo = true
            case "--dimmed": forceDimmed = true
            case "--settings": openSettings = true
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
        guard let f = frozenTime else { return real }
        var c = calendar.dateComponents([.year, .month, .day], from: real)
        c.hour = f.hour; c.minute = f.minute
        // Keep seconds live so animation and the second hand still move.
        c.second = calendar.component(.second, from: real)
        return calendar.date(from: c) ?? real
    }
}
