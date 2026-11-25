import SwiftUI

/// Flat Pokéball glyph. The top shell fills from the bottom up with the charge level,
/// so the ball reads as a battery at a glance; it turns red when low.
struct PokeballGlyph: View {
    var level: Double?          // nil → outline only
    var isCharging = false
    var accent: Color = Palette.electric
    var dimmed = false
    var size: CGFloat = 16

    var body: some View {
        Canvas { ctx, sz in
            let s = min(sz.width, sz.height)
            let lw = max(1, s * 0.09)
            let r = s / 2 - lw / 2
            let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
            let circle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            let low = (level ?? 1) <= MoodEngine.lowBattery && !isCharging
            let fill = dimmed ? Palette.dim : (low ? Palette.lowRed : accent)
            let rim = dimmed ? Palette.faint : Palette.dim

            // Charge fill, clipped to the ball.
            if let level {
                let h = r * 2 * CGFloat(max(0, min(1, level)))
                ctx.drawLayer { layer in
                    layer.clip(to: circle)
                    layer.fill(Path(CGRect(x: c.x - r, y: c.y + r - h, width: r * 2, height: h)),
                               with: .color(fill.opacity(dimmed ? 0.5 : 0.9)))
                }
            }
            ctx.stroke(circle, with: .color(rim), lineWidth: lw)
            // Centre band and button.
            var band = Path()
            band.move(to: CGPoint(x: c.x - r, y: c.y)); band.addLine(to: CGPoint(x: c.x + r, y: c.y))
            ctx.stroke(band, with: .color(.black), lineWidth: lw * 1.8)
            ctx.stroke(band, with: .color(rim), lineWidth: lw * 0.8)
            let br = r * 0.34
            let button = Path(ellipseIn: CGRect(x: c.x - br, y: c.y - br, width: br * 2, height: br * 2))
            ctx.fill(button, with: .color(.black))
            ctx.stroke(button, with: .color(rim), lineWidth: lw)
            if isCharging && !dimmed {
                ctx.fill(Path(ellipseIn: button.boundingRect.insetBy(dx: br * 0.45, dy: br * 0.45)), with: .color(accent))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Pokéball + percentage.
struct PokeballBattery: View {
    let battery: BatterySnapshot
    var accent: Color = Palette.electric
    var dimmed = false
    var size: CGFloat = 15
    var font: Font = .system(size: 13, weight: .semibold, design: .rounded)

    var body: some View {
        HStack(spacing: 4) {
            PokeballGlyph(level: battery.level, isCharging: battery.isCharging, accent: accent, dimmed: dimmed, size: size)
            Text(battery.percentText)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(dimmed ? Palette.dim : (battery.isLow ? Palette.lowRed : Palette.ink))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery \(battery.percentText)\(battery.isCharging ? ", charging" : "")")
    }
}
