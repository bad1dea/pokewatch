import CoreGraphics
import Foundation

/// One imported animation: a 1x sprite sheet cut into frames, with the original timing.
final class SpriteClip: @unchecked Sendable {
    struct Manifest: Decodable, Sendable {
        let id: String
        let style: String
        let variant: String
        let frameWidth: Int
        let frameHeight: Int
        let columns: Int
        let frameCount: Int
        let durationsMs: [Int]
        let totalDurationMs: Int
    }

    let manifest: Manifest
    let style: SpriteStyle
    let shiny: Bool
    private let sheet: CGImage
    private let frames: [CGImage]
    private let ends: [Int]
    private var tinted: [String: [CGImage]] = [:]
    private let lock = NSLock()

    var isStill: Bool { manifest.frameCount == 1 }
    var size: CGSize { CGSize(width: manifest.frameWidth, height: manifest.frameHeight) }

    init?(directory: URL, style: SpriteStyle, shiny: Bool) {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("manifest.json")),
              let m = try? JSONDecoder().decode(Manifest.self, from: data),
              m.frameCount > 0, m.durationsMs.count == m.frameCount, m.columns > 0,
              m.durationsMs.allSatisfy({ $0 > 0 }),
              let sheet = SpriteFiles.loadImage(directory.appendingPathComponent("sheet.png"))
        else { return nil }
        let frames = Self.cut(sheet, m)
        guard frames.count == m.frameCount else { return nil }
        var running = 0
        ends = m.durationsMs.map { running += $0; return running }
        manifest = m
        self.style = style
        self.shiny = shiny
        self.sheet = sheet
        self.frames = frames
    }

    private static func cut(_ sheet: CGImage, _ m: Manifest) -> [CGImage] {
        (0..<m.frameCount).compactMap { i in
            sheet.cropping(to: CGRect(x: (i % m.columns) * m.frameWidth, y: (i / m.columns) * m.frameHeight,
                                      width: m.frameWidth, height: m.frameHeight))
        }
    }

    /// Frame index for a playback position in seconds.
    func frameIndex(at seconds: Double) -> Int {
        guard frames.count > 1, let total = ends.last, total > 0 else { return 0 }
        let t = Int((max(0, seconds) * 1000).truncatingRemainder(dividingBy: Double(total)))
        return ends.firstIndex { $0 > t } ?? 0
    }

    func frame(_ index: Int, shades: [RGB]? = nil) -> CGImage {
        guard let shades else { return frames[index] }
        let key = shades.map { "\($0.r).\($0.g).\($0.b)" }.joined(separator: "|")
        lock.lock(); defer { lock.unlock() }
        if let cached = tinted[key] { return cached[index] }
        guard let recolored = ImageRecolor.shades(sheet, shades) else { return frames[index] }
        let cut = Self.cut(recolored, manifest)
        tinted[key] = cut
        return cut[index]
    }
}

/// Loads clips on demand and keeps only the few most recently used in memory
/// (a large modern sprite decodes to about 3.5 MB).
final class SpriteLibrary: @unchecked Sendable {
    static let shared = SpriteLibrary()

    private let bundle: Bundle
    private var clips: [String: SpriteClip] = [:]
    private var order: [String] = []
    private var existence: [String: Bool] = [:]
    private let lock = NSLock()
    static let capacity = 3

    init(bundle: Bundle = .main) { self.bundle = bundle }

    private func exists(_ id: String, _ style: SpriteStyle, _ shiny: Bool) -> Bool {
        let key = "\(style.rawValue)/\(id)/\(shiny)"
        if let known = existence[key] { return known }
        let found = SpriteFiles.animationDirectory(id: id, style: style, shiny: shiny, bundle: bundle) != nil
        existence[key] = found
        return found
    }

    /// Whether any imported art exists for this Pokémon.
    func hasArt(for id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return SpriteStyle.allCases.contains { exists(id, $0, false) }
    }

    /// The clip to show, following the style fallback chain. Nil when nothing was imported.
    func clip(for id: String, style: SpriteStyle, shiny: Bool) -> SpriteClip? {
        lock.lock(); defer { lock.unlock() }
        guard let (s, sh) = SpriteFiles.resolve(id: id, style: style, shiny: shiny, exists: exists),
              let dir = SpriteFiles.animationDirectory(id: id, style: s, shiny: sh, bundle: bundle) else { return nil }
        let key = "\(s.rawValue)/\(id)/\(sh)"
        if let hit = clips[key] {
            order.removeAll { $0 == key }; order.append(key)
            return hit
        }
        guard let clip = SpriteClip(directory: dir, style: s, shiny: sh) else { return nil }
        clips[key] = clip
        order.append(key)
        while order.count > Self.capacity { clips[order.removeFirst()] = nil }
        return clip
    }

    var cachedCount: Int {
        lock.lock(); defer { lock.unlock() }
        return clips.count
    }
}
