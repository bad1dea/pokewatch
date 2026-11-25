import SwiftUI

/// A character sprite at an integer pixel scale, drawn from the rasterizer cache.
struct SpriteImage: View {
    let character: CharacterDefinition
    var expression: SpriteExpression = .open
    var earTwitch = false
    var tint: SpriteTint = .natural
    var pixel: CGFloat = 4

    var body: some View {
        let size = CGSize(width: CGFloat(character.width) * pixel, height: CGFloat(character.height) * pixel)
        if let cg = SpriteRasterizer.shared.image(for: character, expression: expression, earTwitch: earTwitch, tint: tint) {
            Image(decorative: cg, scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: size.width, height: size.height)
                .accessibilityLabel(character.name)
        } else {
            Color.clear.frame(width: size.width, height: size.height)
        }
    }
}
