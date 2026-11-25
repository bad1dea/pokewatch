import CoreGraphics
import Foundation

/// First frames of imported sprites (`ImportedStills`), decoded once and cached for grids.
enum StillCache {
    private final class Box { let image: CGImage; init(_ i: CGImage) { image = i } }
    nonisolated(unsafe) private static let cache: NSCache<NSString, Box> = {
        let c = NSCache<NSString, Box>()
        c.countLimit = 600
        return c
    }()

    static func image(id: String, style: SpriteStyle, shiny: Bool = false) -> CGImage? {
        let key = "\(style.rawValue)/\(id)/\(shiny)" as NSString
        if let hit = cache.object(forKey: key) { return hit.image }
        guard let url = SpriteFiles.stillURL(id: id, style: style, shiny: shiny)
                ?? (shiny ? SpriteFiles.stillURL(id: id, style: style, shiny: false) : nil),
              let image = SpriteFiles.loadImage(url) else { return nil }
        cache.setObject(Box(image), forKey: key)
        return image
    }
}
