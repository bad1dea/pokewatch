import Foundation

/// How a character moves while idle. Unknown values in a JSON file fall back to `.bounce`
/// so third-party character files never fail to load because of a typo.
enum IdleStyle: String, Codable, Sendable, CaseIterable {
    case bounce, sway, float, breathe, waddle, wobble

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = IdleStyle(rawValue: raw) ?? .bounce
    }
}

/// The ambient particle effect a character emits.
enum ParticleElement: String, Codable, Sendable, CaseIterable {
    case spark, sparkle, wisp, zzz, ember, bubble, leaf, psychic, moon, confused

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ParticleElement(rawValue: raw) ?? .sparkle
    }
}

/// A data-driven Pokémon companion. Every character is a `*.pokemon.json` file:
/// pixel art as rows of palette keys plus personality parameters. Adding a character
/// means adding a file — no Swift changes. See Documentation/ADDING_CHARACTERS.md.
struct CharacterDefinition: Codable, Identifiable, Hashable, Sendable {
    struct Eyes: Codable, Hashable, Sendable {
        /// Palette keys that make up the eyes (pupil + highlight).
        var keys: [String]
        /// Palette key painted over the eye when the lid closes.
        var fill: String
        /// Palette key used for the closed-eye line.
        var line: String
    }

    struct Personality: Codable, Hashable, Sendable {
        var idleStyle: IdleStyle
        /// 0…1 — how readily it gets excited.
        var energy: Double
        /// 0…1 — how readily it dozes off.
        var sleepiness: Double
        /// Idle cycle speed in radians per second multiplier.
        var bobSpeed: Double
        /// Idle motion amplitude in sprite pixels.
        var bobAmplitude: Double
        /// Mean seconds between blinks.
        var blinkInterval: Double
        /// Jump height in sprite pixels.
        var hopHeight: Double
        /// Awake at night, drowsy in the morning.
        var nightOwl: Bool
        /// Falls asleep when your step count stops moving.
        var sleepsWhenIdle: Bool
        /// Gets excited as the step goal approaches.
        var stepLover: Bool
    }

    struct Lines: Codable, Hashable, Sendable {
        var idle: String
        var happy: String
        var excited: String
        var celebrate: String
        var tired: String
        var charging: String
        var sleep: String
        var wake: String
    }

    var id: String
    var name: String
    var dexNumber: Int
    var category: String
    var type: String
    var entry: String
    var element: ParticleElement
    var accentHex: String
    var palette: [String: String]
    var eyes: Eyes
    var earRows: Int
    var personality: Personality
    var lines: Lines
    var sprite: [String]
    /// Optional explicit sort position in pickers.
    var order: Int?

    var width: Int { sprite.map(\.count).max() ?? 0 }
    var height: Int { sprite.count }
    var dexLabel: String { String(format: "No.%03d", dexNumber) }

    /// Stable per-character seed so blink timing differs between characters
    /// but is identical across launches.
    var seed: Int { id.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF } }
}

extension CharacterDefinition {
    enum ValidationError: Error, Equatable {
        case emptySprite(String)
        case unknownPaletteKey(String, String)
        case badColor(String, String)
        case missingEyeKey(String, String)
    }

    func validate() throws {
        guard !sprite.isEmpty, width > 0 else { throw ValidationError.emptySprite(id) }
        for (key, hex) in palette where RGB(hex: hex) == nil {
            throw ValidationError.badColor(id, key)
        }
        guard RGB(hex: accentHex) != nil else { throw ValidationError.badColor(id, "accentHex") }
        for row in sprite {
            for ch in row where ch != "." && palette[String(ch)] == nil {
                throw ValidationError.unknownPaletteKey(id, String(ch))
            }
        }
        for key in eyes.keys + [eyes.fill, eyes.line] where palette[key] == nil {
            throw ValidationError.missingEyeKey(id, key)
        }
    }

    func line(for mood: Mood) -> String {
        switch mood {
        case .sleeping: lines.sleep
        case .drowsy, .tired: lines.tired
        case .calm: lines.idle
        case .happy: lines.happy
        case .excited: lines.excited
        case .celebrating: lines.celebrate
        case .charging: lines.charging
        }
    }

    /// Used only if no character files could be loaded at all.
    static let placeholder = CharacterDefinition(
        id: "placeholder", name: "Egg", dexNumber: 0, category: "Mystery", type: "Normal",
        entry: "Something is about to hatch.", element: .sparkle, accentHex: "#FFE100",
        palette: ["K": "#5A5A5A", "W": "#EDEDED", "E": "#202020"],
        eyes: Eyes(keys: ["E"], fill: "W", line: "K"), earRows: 0,
        personality: Personality(idleStyle: .wobble, energy: 0.3, sleepiness: 0.5, bobSpeed: 1, bobAmplitude: 0.5,
                                 blinkInterval: 4, hopHeight: 1, nightOwl: false, sleepsWhenIdle: false, stepLover: false),
        lines: Lines(idle: "...", happy: "!", excited: "!!", celebrate: "!!!", tired: "...", charging: "~", sleep: "zzz", wake: "?"),
        sprite: ["...KKKK...", "..KWWWWK..", ".KWWWWWWK.", ".KWEWWEWK.", "KWWWWWWWWK",
                 "KWWWWWWWWK", "KWWWWWWWWK", ".KWWWWWWK.", "..KKKKKK.."],
        order: nil)
}

/// 8-bit RGB colour parsed from `#RRGGBB`.
struct RGB: Hashable, Sendable {
    var r: UInt8, g: UInt8, b: UInt8

    init(r: UInt8, g: UInt8, b: UInt8) { self.r = r; self.g = g; self.b = b }

    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        r = UInt8((v >> 16) & 0xFF); g = UInt8((v >> 8) & 0xFF); b = UInt8(v & 0xFF)
    }

    /// Relative luminance 0…1 (Rec. 709 weights on gamma-encoded values; good enough for palette mapping).
    var luminance: Double { (0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)) / 255 }

    func scaled(_ f: Double) -> RGB {
        func s(_ c: UInt8) -> UInt8 { UInt8(max(0, min(255, (Double(c) * f).rounded()))) }
        return RGB(r: s(r), g: s(g), b: s(b))
    }
}
