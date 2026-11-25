import CoreGraphics
import Foundation
import ImageIO

/// Art style for the companion: which generation's battle sprites to show.
/// Sprites are imported at build time by `Scripts/import_sprites.py`.
enum SpriteStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case gen1, gen2, gen3, gen4, gen5, modern
    var id: String { rawValue }

    var title: String {
        switch self {
        case .gen1: "Gen I · Yellow"
        case .gen2: "Gen II · Crystal"
        case .gen3: "Gen III · Emerald"
        case .gen4: "Gen IV · HeartGold"
        case .gen5: "Gen V · Black/White"
        case .modern: "Modern"
        }
    }

    var shortTitle: String {
        switch self {
        case .gen1: "Gen I"
        case .gen2: "Gen II"
        case .gen3: "Gen III"
        case .gen4: "Gen IV"
        case .gen5: "Gen V"
        case .modern: "Modern"
        }
    }

    /// Styles to try when a Pokémon doesn't exist in this one: newer generations first
    /// (a Pokémon introduced later keeps a similar era look), then older ones.
    var fallbackChain: [SpriteStyle] {
        let all = Self.allCases
        let i = all.firstIndex(of: self)!
        return [self] + all[(i + 1)...] + all[..<i].reversed()
    }

    static let `default`: SpriteStyle = .gen5

    /// Last national dex number in this style's games.
    var lastDex: Int {
        switch self {
        case .gen1: 151
        case .gen2: 251
        case .gen3: 386
        case .gen4: 493
        case .gen5: 649
        case .modern: 1025
        }
    }
}

/// Which artwork to draw for the companion.
struct ArtChoice: Equatable, Sendable {
    var style: SpriteStyle = .default
    var shiny = false
}

/// Locates imported sprite files. Paths: `ImportedSprites/<style>/<id>/<variant>/`
/// (animations, app) and `ImportedStills/<style>/<id>/<variant>.png` (first frames, widgets).
enum SpriteFiles {
    /// Sprite folders installed after the app (packs sent from the iPhone), searched before the
    /// bundle. Each root contains `<style>/<id>/<variant>/`.
    nonisolated(unsafe) static var extraRoots: [URL] = []

    static func animationDirectory(id: String, style: SpriteStyle, shiny: Bool, bundle: Bundle = .main) -> URL? {
        let sub = "\(style.rawValue)/\(id)/\(shiny ? "shiny" : "normal")"
        var roots = extraRoots
        if let root = bundle.resourceURL?.appendingPathComponent("ImportedSprites", isDirectory: true) { roots.append(root) }
        for root in roots {
            let dir = root.appendingPathComponent(sub, isDirectory: true)
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("manifest.json").path) { return dir }
        }
        return nil
    }

    /// Bundles that carry `ImportedStills`: the main bundle (widget extension) and, from the app,
    /// the embedded widget extension, so the first frames are bundled only once.
    static let stillBundles: [Bundle] = {
        var bundles: [Bundle] = [.main]
        if let plugins = Bundle.main.builtInPlugInsURL,
           let widget = Bundle(url: plugins.appendingPathComponent("PokeWatchWidgets.appex")) {
            bundles.append(widget)
        }
        return bundles
    }()

    static func stillURL(id: String, style: SpriteStyle, shiny: Bool, bundles: [Bundle] = stillBundles) -> URL? {
        for bundle in bundles {
            guard let root = bundle.resourceURL?.appendingPathComponent("ImportedStills", isDirectory: true) else { continue }
            let url = root.appendingPathComponent("\(style.rawValue)/\(id)/\(shiny ? "shiny" : "normal").png")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    /// First style in the fallback chain that has art for this Pokémon (shiny falls back to normal).
    /// Only complications use the chain; faces and pickers are era-accurate.
    static func resolve(id: String, style: SpriteStyle, shiny: Bool,
                        exists: (String, SpriteStyle, Bool) -> Bool) -> (SpriteStyle, Bool)? {
        for s in style.fallbackChain {
            if shiny && exists(id, s, true) { return (s, true) }
            if exists(id, s, false) { return (s, false) }
        }
        return nil
    }

    static func loadImage(_ url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }
}

/// Pixel recolouring for imported art (Game Boy shades, dimming).
enum ImageRecolor {
    static func shades(_ image: CGImage, _ shades: [RGB]) -> CGImage? {
        guard shades.count >= 4 else { return image }
        return map(image) { r, g, b in
            let l = (0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)) / 255
            let s = shades[l > 0.72 ? 0 : l > 0.48 ? 1 : l > 0.22 ? 2 : 3]
            return (s.r, s.g, s.b)
        }
    }

    static func map(_ image: CGImage, _ f: (UInt8, UInt8, UInt8) -> (UInt8, UInt8, UInt8)) -> CGImage? {
        let w = image.width, h = image.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        for i in stride(from: 0, to: bytes.count, by: 4) where bytes[i + 3] > 0 {
            let a = Double(bytes[i + 3]) / 255
            // Un-premultiply, map, re-premultiply.
            let (r, g, b) = f(UInt8(min(255, Double(bytes[i]) / a)), UInt8(min(255, Double(bytes[i + 1]) / a)),
                              UInt8(min(255, Double(bytes[i + 2]) / a)))
            bytes[i] = UInt8(Double(r) * a); bytes[i + 1] = UInt8(Double(g) * a); bytes[i + 2] = UInt8(Double(b) * a)
        }
        return ctx.makeImage()
    }
}
