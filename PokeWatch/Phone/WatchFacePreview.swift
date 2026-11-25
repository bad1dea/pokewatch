import SwiftUI

/// A live watch face at true Ultra size (211 × 257 pt), clipped to the measured screen shape
/// and set in a dark bezel, scaled to `width`.
struct WatchFacePreview: View {
    @Environment(PhoneModel.self) private var model
    let face: FaceStyle
    var width: CGFloat
    var animate = true

    static let screen = CGSize(width: 211, height: 257)

    var body: some View {
        let k = width / Self.screen.width
        let bezel = 10 * k
        TimelineView(.animation(minimumInterval: 1 / 12, paused: !animate)) { tl in
            FaceView(style: face, context: context(at: tl.date))
                .frame(width: Self.screen.width, height: Self.screen.height)
                .clipShape(WatchScreenShape())
                .scaleEffect(k, anchor: .topLeading)
                .frame(width: width, height: Self.screen.height * k, alignment: .topLeading)
        }
        .padding(bezel)
        .background(WatchScreenShape(expand: bezel / k).scale(k, anchor: .topLeading)
            .fill(Color(white: 0.09))
            .frame(width: width + bezel * 2, height: Self.screen.height * k + bezel * 2, alignment: .topLeading))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(face.title) face with \(model.character.name)")
    }

    private func context(at date: Date) -> FaceContext {
        let s = model.settings
        let style: SpriteStyle = face == .yellow && model.registry.isAvailable(s.characterID, in: .gen1) ? .gen1 : s.spriteStyle
        return .sample(date: date, characterID: s.characterID, mood: face == .sleeping ? .sleeping : .happy,
                       options: FaceOptions(s), art: ArtChoice(style: style, shiny: s.shiny), variant: s.variant)
    }
}

/// The Ultra display outline from `ScreenShape`'s measured corner profile, at 211 × 257,
/// optionally grown by `expand` points (for the bezel).
struct WatchScreenShape: Shape {
    var expand: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let w = WatchFacePreview.screen.width, h = WatchFacePreview.screen.height
        let e = expand
        let profile = ScreenShape.profile
        var p = Path()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x + e, y: y + e) }
        // Top edge, left to right, then corners in clockwise order.
        let top = profile.map { (d, inset) in (inset, d) }
        p.move(to: pt(top[0].0 - e, -e))
        p.addLine(to: pt(w - top[0].0 + e, -e))
        for (inset, d) in top.dropFirst() { p.addLine(to: pt(w - inset + e, d - e)) }
        for (inset, d) in top.reversed() { p.addLine(to: pt(w - inset + e, h - d + e)) }
        for (inset, d) in top { p.addLine(to: pt(inset - e, h - d + e)) }
        for (inset, d) in top.reversed() { p.addLine(to: pt(inset - e, d - e)) }
        p.closeSubpath()
        return p
    }
}
