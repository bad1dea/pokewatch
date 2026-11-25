import SwiftUI

/// Small, deterministic particle effects. Positions are a pure function of time,
/// so there is no simulation state and a paused timeline costs nothing.
struct ParticleField: View {
    let element: ParticleElement
    let time: TimeInterval
    /// 0…1 — scales particle count.
    let level: Double
    var pixel: CGFloat = 3
    var color: Color?

    var body: some View {
        Canvas { ctx, size in
            let count = Int((level * 7).rounded())
            guard count > 0 else { return }
            for i in 0..<count {
                draw(i, in: &ctx, size: size)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func n(_ i: Int, _ salt: Double) -> Double { CompanionAnimator.noise(Double(i) + salt, element.hashSeed) }

    private func draw(_ i: Int, in ctx: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let life = 1.4 + n(i, 0.1) * 1.6
        let raw = time / life + n(i, 0.2)
        let phase = raw - floor(raw)
        let cycle = floor(raw)
        let fade = sin(phase * .pi)
        let p = pixel

        func square(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ c: Color, _ a: Double) {
            ctx.fill(Path(CGRect(x: (x / p).rounded() * p, y: (y / p).rounded() * p, width: s, height: s)),
                     with: .color(c.opacity(a)))
        }

        switch element {
        case .spark:
            // Short zig-zag bolts that flash at random spots around the sprite.
            guard phase < 0.22 else { return }
            let x = w * (0.1 + 0.8 * CompanionAnimator.noise(cycle + Double(i), 11))
            let y = h * (0.05 + 0.6 * CompanionAnimator.noise(cycle + Double(i), 23))
            let c = color ?? Color(hex: "#FFE14A")
            let a = 1 - phase / 0.22
            square(x, y, p, c, a)
            square(x + p, y + p, p, c, a)
            square(x, y + 2 * p, p, c, a)
            square(x + p, y + 3 * p, p, c, a * 0.6)
        case .sparkle, .psychic:
            let c = color ?? (element == .psychic ? Color(hex: "#FF9ACB") : Color(hex: "#FFF2C0"))
            let angle = phase * 2 * .pi + n(i, 0.3) * 6
            let radius = w * (0.32 + 0.12 * n(i, 0.4))
            let x = w / 2 + cos(angle) * radius
            let y = h * 0.5 + sin(angle) * radius * 0.6
            square(x, y - p, p, c, fade)
            square(x - p, y, p, c, fade * 0.7)
            square(x + p, y, p, c, fade * 0.7)
            square(x, y + p, p, c, fade)
            square(x, y, p, c, fade)
        case .wisp:
            let c = color ?? Color(hex: "#8E6BD6")
            let x = w * (0.1 + 0.8 * n(i, 0.5)) + sin(time * 1.3 + Double(i)) * p * 2
            let y = h * (0.9 - 0.8 * phase)
            let s = p * (2 - phase)
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s * 2, height: s * 2)), with: .color(c.opacity(fade * 0.55)))
        case .zzz:
            drawZ(i, phase: phase, fade: fade, ctx: &ctx, size: size)
        case .ember:
            let c = i % 2 == 0 ? (color ?? Color(hex: "#FF7A2A")) : Color(hex: "#FFD23A")
            let x = w * (0.55 + 0.35 * n(i, 0.6)) + sin(time * 4 + Double(i)) * p
            let y = h * (0.55 - 0.5 * phase)
            square(x, y, p, c, fade * (0.6 + 0.4 * sin(time * 20 + Double(i))))
        case .bubble:
            let c = color ?? Color(hex: "#8FD8F8")
            let x = w * (0.15 + 0.7 * n(i, 0.7)) + sin(time * 2 + Double(i)) * p * 1.5
            let y = h * (0.85 - 0.8 * phase)
            let r = p * (1.2 + n(i, 0.8))
            ctx.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                       with: .color(c.opacity(fade * 0.8)), lineWidth: max(1, p * 0.5))
        case .leaf:
            let c = i % 2 == 0 ? (color ?? Color(hex: "#7CD67A")) : Color(hex: "#4FA84A")
            let x = w * (0.1 + 0.8 * n(i, 0.9)) + sin(time * 1.5 + Double(i)) * p * 3
            let y = h * (0.05 + 0.85 * phase)
            square(x, y, p, c, fade)
            square(x + p, y + (sin(time * 3 + Double(i)) > 0 ? p : -p) * 0.0, p, c, fade * 0.6)
        case .moon:
            let c = color ?? Color(hex: "#FFD34A")
            let x = w * (0.15 + 0.7 * n(i, 1.1))
            let y = h * (0.1 + 0.5 * n(i, 1.2))
            let twinkle = max(0, sin(phase * 2 * .pi))
            square(x, y, p, c, twinkle)
            if twinkle > 0.7 {
                square(x - p, y, p, c, twinkle * 0.4); square(x + p, y, p, c, twinkle * 0.4)
            }
        case .confused:
            guard i < 3 else { return }
            let angle = time * 2.2 + Double(i) * 2.1
            let x = w / 2 + cos(angle) * w * 0.25 - p * 2
            let y = h * 0.06 + sin(angle) * p * 2
            ctx.draw(Text("?").font(.system(size: p * 4, weight: .heavy, design: .rounded))
                .foregroundStyle((color ?? Color(hex: "#8FD8F8")).opacity(0.85)), at: CGPoint(x: x, y: y))
        }
    }

    private func drawZ(_ i: Int, phase: Double, fade: Double, ctx: inout GraphicsContext, size: CGSize) {
        guard i < 3 else { return }
        let c = color ?? Color(hex: "#C9D6FF")
        let x = size.width * (0.62 + 0.25 * phase) + CGFloat(i) * pixel
        let y = size.height * (0.4 - 0.4 * phase)
        let s = pixel * (0.8 + 0.6 * phase)
        let glyph = PixelFont.path(for: "Z", pixel: s / 1.4)
        ctx.fill(glyph.offsetBy(dx: x, dy: y), with: .color(c.opacity(fade * 0.9)))
    }
}

private extension ParticleElement {
    var hashSeed: Int { rawValue.unicodeScalars.reduce(3) { ($0 &* 33 &+ Int($1.value)) & 0xFFFF } }
}
