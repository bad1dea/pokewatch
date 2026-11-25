import CoreGraphics
import Foundation

enum SpriteExpression: String, Sendable, CaseIterable {
    case open, closed, happy, tired
}

/// Colour treatment applied when rasterizing a sprite.
enum SpriteTint: Hashable, Sendable {
    case natural
    /// Every colour multiplied by `percent`/100 — used for Always-On and evening faces.
    case dimmed(Int)
    /// Four-shade palette (lightest → darkest), mapped by luminance — Game Boy style.
    case shades([RGB])
    /// Single flat colour for every opaque pixel.
    case silhouette(RGB)
}

/// Turns a character definition into pixel grids and cached `CGImage`s.
/// Each (character, expression, ear pose, tint) combination is rasterized once
/// and then reused for every frame, so animation only costs a transform.
final class SpriteRasterizer: @unchecked Sendable {
    static let shared = SpriteRasterizer()

    private struct Key: Hashable {
        let id: String
        let expression: SpriteExpression
        let earTwitch: Bool
        let tint: SpriteTint
    }

    private var cache: [Key: CGImage] = [:]
    private let lock = NSLock()

    func image(for character: CharacterDefinition, expression: SpriteExpression = .open,
               earTwitch: Bool = false, tint: SpriteTint = .natural) -> CGImage? {
        let key = Key(id: character.id, expression: expression, earTwitch: earTwitch, tint: tint)
        lock.lock(); defer { lock.unlock() }
        if let hit = cache[key] { return hit }
        let image = Self.rasterize(character, expression: expression, earTwitch: earTwitch, tint: tint)
        if let image { cache[key] = image }
        return image
    }

    func purge() {
        lock.lock(); cache.removeAll(); lock.unlock()
    }

    var cachedCount: Int {
        lock.lock(); defer { lock.unlock() }
        return cache.count
    }

    /// Palette-key grid after applying the expression and ear pose. `nil` = transparent.
    static func grid(for c: CharacterDefinition, expression: SpriteExpression, earTwitch: Bool) -> [[String?]] {
        let w = c.width, h = c.height
        guard let rows = c.sprite, let eyes = c.eyes else { return [] }
        let earRows = c.earRows ?? 0
        let src: [[String?]] = rows.map { row in
            var cells = row.map { $0 == "." ? nil : String($0) } as [String?]
            if cells.count < w { cells += Array(repeating: nil, count: w - cells.count) }
            return cells
        }
        let eyeKeys = Set(eyes.keys)
        func isEye(_ x: Int, _ y: Int) -> Bool {
            guard y >= 0, y < h, x >= 0, x < w, let k = src[y][x] else { return false }
            return eyeKeys.contains(k)
        }
        var out = src
        if expression != .open {
            for y in 0..<h {
                for x in 0..<w where isEye(x, y) {
                    let above = isEye(x, y - 1), below = isEye(x, y + 1)
                    switch expression {
                    case .open: break
                    case .closed: out[y][x] = below ? eyes.fill : eyes.line
                    case .happy:
                        if !above && !below && y > 0 && isEye(x - 1, y) && isEye(x + 1, y) {
                            // Single-row eye: lift the middle to make a ^ shape.
                            out[y][x] = eyes.fill
                            out[y - 1][x] = eyes.line
                        } else {
                            out[y][x] = above ? eyes.fill : eyes.line
                        }
                    case .tired: if !above && below { out[y][x] = eyes.line }
                    }
                }
            }
        }
        if earTwitch && earRows > 0 {
            // Flick the left ear outward by one pixel.
            let half = w / 2
            for y in 0..<min(earRows, h) {
                for x in 0..<half {
                    out[y][x] = x + 1 < half ? out[y][x + 1] : nil
                }
            }
        }
        return out
    }

    static func color(for key: String, in c: CharacterDefinition, tint: SpriteTint) -> RGB? {
        guard let hex = c.palette?[key], let base = RGB(hex: hex) else { return nil }
        switch tint {
        case .natural: return base
        case .dimmed(let pct): return base.scaled(Double(pct) / 100)
        case .silhouette(let rgb): return rgb
        case .shades(let shades):
            guard shades.count >= 4 else { return base }
            let l = base.luminance
            let i = l > 0.72 ? 0 : l > 0.48 ? 1 : l > 0.22 ? 2 : 3
            return shades[i]
        }
    }

    static func rasterize(_ c: CharacterDefinition, expression: SpriteExpression,
                          earTwitch: Bool, tint: SpriteTint) -> CGImage? {
        let g = grid(for: c, expression: expression, earTwitch: earTwitch)
        let w = c.width, h = c.height
        guard w > 0, h > 0, g.count == h else { return nil }
        var colors: [String: RGB] = [:]
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                guard let key = g[y][x] else { continue }
                let rgb: RGB
                if let cached = colors[key] { rgb = cached } else {
                    guard let resolved = color(for: key, in: c, tint: tint) else { continue }
                    colors[key] = resolved; rgb = resolved
                }
                let i = (y * w + x) * 4
                bytes[i] = rgb.r; bytes[i + 1] = rgb.g; bytes[i + 2] = rgb.b; bytes[i + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
