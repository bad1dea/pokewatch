import SwiftUI

/// The animated companion: cached sprite + transform + particles + speech.
/// Everything comes from a precomputed `CompanionPose`, so this view does no timing.
struct CompanionView: View {
    let character: CharacterDefinition
    let pose: CompanionPose
    let time: TimeInterval
    var pixel: CGFloat = 4
    var tint: SpriteTint = .natural
    var particles = true
    var particleColor: Color?
    var showSpeech = true

    var body: some View {
        let w = CGFloat(character.width) * pixel
        let h = CGFloat(character.height) * pixel
        ZStack(alignment: .bottom) {
            if particles && pose.particleLevel > 0 {
                ParticleField(element: pose.showsZ ? .zzz : character.element, time: time,
                              level: pose.particleLevel, pixel: max(2, pixel * 0.75), color: particleColor)
                    .frame(width: w * 1.6, height: h * 1.3)
            } else if particles && pose.showsZ {
                ParticleField(element: .zzz, time: time, level: 0.3, pixel: max(2, pixel * 0.75), color: particleColor)
                    .frame(width: w * 1.6, height: h * 1.3)
            }
            SpriteImage(character: character, expression: pose.expression, earTwitch: pose.earTwitch,
                        tint: tint, pixel: pixel)
                .scaleEffect(x: pose.scaleX * (pose.flipped ? -1 : 1), y: pose.scaleY, anchor: .bottom)
                .rotationEffect(.degrees(pose.rotation), anchor: .bottom)
                .offset(x: pose.dx * pixel, y: pose.dy * pixel)
        }
        .frame(width: w, height: h, alignment: .bottom)
        .overlay(alignment: .top) {
            if showSpeech, let speech = pose.speech {
                SpeechBubble(text: speech)
                    .fixedSize()
                    .offset(y: -18)
                    .transition(.opacity)
            }
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
