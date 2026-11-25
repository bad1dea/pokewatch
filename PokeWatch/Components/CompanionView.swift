import SwiftUI

/// The animated companion, fitted into `box`: imported sprite (or fallback pixel art),
/// transform from the pose, particles and speech. All timing comes from `time`
/// and the precomputed pose; this view keeps no state.
struct CompanionView: View {
    @Environment(\.displayScale) private var displayScale

    let character: CharacterDefinition
    let pose: CompanionPose
    let time: TimeInterval
    var box: CGSize
    var art = ArtChoice()
    var tint: SpriteTint = .natural
    var particles = true
    var particleColor: Color?
    var showSpeech = true
    /// Fraction of the box height the sprite may fill; the rest is headroom for hops.
    var fill: CGFloat = 0.86

    var body: some View {
        let clip = SpriteLibrary.shared.clip(for: character.id, style: art.style, shiny: art.shiny)
        let layout = Self.layout(clip: clip, character: character, box: box, fill: fill, displayScale: displayScale)

        ZStack(alignment: .bottom) {
            if particles && (pose.particleLevel > 0 || pose.showsZ) {
                ParticleField(element: pose.showsZ ? .zzz : character.element, time: time,
                              level: max(pose.particleLevel, pose.showsZ ? 0.3 : 0),
                              pixel: max(2, min(4, layout.unit * 1.5)), color: particleColor)
                    .frame(width: box.width, height: box.height)
            }
            sprite(clip: clip, size: layout.size)
                .scaleEffect(x: pose.scaleX * (pose.flipped ? -1 : 1), y: pose.scaleY, anchor: .bottom)
                .rotationEffect(.degrees(pose.rotation), anchor: .bottom)
                .offset(x: pose.dx * layout.unit, y: pose.dy * layout.unit)
        }
        .frame(width: box.width, height: box.height, alignment: .bottom)
        .overlay(alignment: .topTrailing) {
            if showSpeech, let speech = pose.speech {
                SpeechBubble(text: speech).fixedSize()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(character.name)
    }

    struct Layout: Equatable {
        /// Displayed size of the sprite in points.
        var size: CGSize
        /// Points per sprite pixel (pose offsets are in sprite pixels).
        var unit: CGFloat
    }

    /// Largest whole-device-pixel scale that fits the box, so pixels stay crisp and square.
    static func layout(clip: SpriteClip?, character: CharacterDefinition, box: CGSize, fill: CGFloat,
                       displayScale: CGFloat) -> Layout {
        let ds = max(1, displayScale)
        let source: CGSize = clip?.size ?? CGSize(width: max(1, character.width), height: max(1, character.height))
        let fitW = box.width * ds / source.width
        let fitH = box.height * fill * ds / source.height
        let scale = max(1, floor(min(fitW, fitH)))
        let unit = scale / ds
        return Layout(size: CGSize(width: source.width * unit, height: source.height * unit), unit: unit)
    }

    @ViewBuilder
    private func sprite(clip: SpriteClip?, size: CGSize) -> some View {
        if let clip {
            let index = pose.playbackRate <= 0 ? 0 : clip.frameIndex(at: time * pose.playbackRate)
            switch tint {
            case .natural:
                Image(decorative: clip.frame(index), scale: 1).resizable().interpolation(.none)
                    .frame(width: size.width, height: size.height)
            case .dimmed(let pct):
                Image(decorative: clip.frame(index), scale: 1).resizable().interpolation(.none)
                    .frame(width: size.width, height: size.height)
                    .saturation(0.7)
                    .opacity(Double(pct) / 100)
            case .shades(let shades):
                Image(decorative: clip.frame(index, shades: shades), scale: 1).resizable().interpolation(.none)
                    .frame(width: size.width, height: size.height)
            case .silhouette(let rgb):
                Image(decorative: clip.frame(index), scale: 1).resizable().interpolation(.none)
                    .renderingMode(.template)
                    .foregroundStyle(Color(rgb))
                    .frame(width: size.width, height: size.height)
            }
        } else if let cg = SpriteRasterizer.shared.image(for: character, expression: pose.expression,
                                                          earTwitch: pose.earTwitch, tint: tint) {
            Image(decorative: cg, scale: 1).resizable().interpolation(.none)
                .frame(width: size.width, height: size.height)
        } else {
            Color.clear.frame(width: size.width, height: size.height)
        }
    }
}

/// Small pixel speech bubble.
struct SpeechBubble: View {
    let text: String
    var color: Color = Palette.ink

    var body: some View {
        PixelText(text: text, pixel: 1.5, color: .black)
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .background(color, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
    }
}
