import SwiftUI

/// 06 — Analog. Pokéball dial; the companion moves to whichever part of the dial
/// the hands are not covering.
struct AnalogFace: View {
    let ctx: FaceContext
    var onTapCompanion: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let R = min(W, H) / 2 - 5
            let center = CGPoint(x: W / 2, y: H / 2)
            let clock = ctx.clock
            let sec = Double(clock.secondValue)
            let minute = Double(clock.minuteValue) + sec / 60
            let hour = Double(clock.hour24 % 12) + minute / 60
            let minuteAngle = minute / 60 * 360
            let hourAngle = hour / 12 * 360
            let spot = Self.companionAngle(hour: hourAngle, minute: minuteAngle)
            let px: CGFloat = max(2, (R / 34).rounded(.down))
            let spotR = R * 0.5
            let spotPoint = CGPoint(x: center.x + CGFloat(sin(spot * .pi / 180)) * spotR,
                                    y: center.y - CGFloat(cos(spot * .pi / 180)) * spotR)

            ZStack {
                PokeballDial(dimmed: ctx.dimmed, accent: ctx.accent)
                    .frame(width: R * 2, height: R * 2)
                    .position(center)

                if ctx.showCompanion {
                    CompanionView(character: ctx.character, pose: ctx.pose, time: ctx.time, pixel: px,
                                  tint: ctx.spriteTint(), particles: ctx.particlesEnabled && !ctx.dimmed, showSpeech: false)
                        .companionTapTarget(onTapCompanion)
                        .position(spotPoint)
                        .animation(.smooth(duration: 0.8), value: spot)
                }

                Hand(length: R * 0.52, width: 6, angle: hourAngle)
                    .fill(ctx.dimmed ? Palette.dim : Palette.ink)
                    .frame(width: W, height: H)
                Hand(length: R * 0.82, width: 4, angle: minuteAngle)
                    .fill(ctx.dimmed ? Palette.dim : Palette.ink)
                    .frame(width: W, height: H)
                if ctx.options.analogSeconds && ctx.showSeconds {
                    Hand(length: R * 0.9, width: 1.5, angle: sec / 60 * 360, tail: R * 0.14)
                        .fill(ctx.accent)
                        .frame(width: W, height: H)
                }
                Circle().fill(Color.black).frame(width: 10, height: 10).position(center)
                Circle().stroke(ctx.dimmed ? Palette.dim : ctx.accent, lineWidth: 2).frame(width: 10, height: 10).position(center)

                // Corners outside the dial.
                if ctx.options.showDate {
                    Text(ClockFormatter.shortDate(ctx.date))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ctx.dimmed ? Palette.dim : ctx.accent)
                        .position(x: 30, y: 14)
                }
                if ctx.options.showBattery {
                    PokeballGlyph(level: ctx.battery.level, isCharging: ctx.battery.isCharging,
                                  accent: ctx.accent, dimmed: ctx.dimmed, size: 15)
                        .position(x: 16, y: H - 14)
                }
                if ctx.options.showActivity, let steps = ctx.activity.steps {
                    Text(steps.compactSteps)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ctx.dimmed ? Palette.dim : Palette.ink)
                        .position(x: W - 26, y: H - 14)
                }
            }
        }
    }

    /// Picks the 30°-step position whose angular distance to both hands is largest.
    static func companionAngle(hour: Double, minute: Double) -> Double {
        func dist(_ a: Double, _ b: Double) -> Double {
            let d = abs((a - b).truncatingRemainder(dividingBy: 360))
            return min(d, 360 - d)
        }
        var best = 180.0, bestScore = -1.0
        for step in 0..<12 {
            let a = Double(step) * 30
            // Prefer the lower half slightly (sprites sit better there).
            let bias = (a > 90 && a < 270) ? 6.0 : 0
            let score = min(dist(a, hour), dist(a, minute)) + bias
            if score > bestScore { bestScore = score; best = a }
        }
        return best
    }
}

private struct Hand: Shape {
    let length: CGFloat
    let width: CGFloat
    let angle: Double
    var tail: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = CGRect(x: c.x - width / 2, y: c.y - length, width: width, height: length + tail)
        return Path(roundedRect: r, cornerRadius: width / 2)
            .applying(CGAffineTransform(translationX: -c.x, y: -c.y)
                .concatenating(CGAffineTransform(rotationAngle: angle * .pi / 180))
                .concatenating(CGAffineTransform(translationX: c.x, y: c.y)))
    }
}

/// Flat Pokéball dial: red upper rim, pale lower rim, the equator band, minute track.
private struct PokeballDial: View {
    let dimmed: Bool
    let accent: Color

    var body: some View {
        Canvas { g, size in
            let R = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let rim: CGFloat = 3
            let red = dimmed ? Color(hex: "#4A1A16") : Color(hex: "#E8433A")
            let pale = dimmed ? Palette.faint : Palette.ink.opacity(0.55)

            var top = Path()
            top.addArc(center: c, radius: R - rim / 2, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            g.stroke(top, with: .color(red), lineWidth: rim)
            var bottom = Path()
            bottom.addArc(center: c, radius: R - rim / 2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            g.stroke(bottom, with: .color(pale), lineWidth: rim)

            // Equator band with the button ring.
            let button: CGFloat = R * 0.16
            for sign in [-1.0, 1.0] {
                var band = Path()
                band.move(to: CGPoint(x: c.x + CGFloat(sign) * (R - rim), y: c.y))
                band.addLine(to: CGPoint(x: c.x + CGFloat(sign) * button, y: c.y))
                g.stroke(band, with: .color(dimmed ? Palette.faint : Palette.faint.opacity(1.4)), lineWidth: 2)
            }
            g.stroke(Path(ellipseIn: CGRect(x: c.x - button, y: c.y - button, width: button * 2, height: button * 2)),
                     with: .color(dimmed ? Palette.faint : Palette.dim.opacity(0.6)), lineWidth: 2)

            // Minute + hour ticks.
            for i in 0..<60 {
                let isHour = i % 5 == 0
                let a = Double(i) / 60 * 2 * .pi
                let outer = R - rim - 3
                let inner = outer - (isHour ? (i % 15 == 0 ? 9 : 6) : 2.5)
                var p = Path()
                p.move(to: CGPoint(x: c.x + sin(a) * inner, y: c.y - cos(a) * inner))
                p.addLine(to: CGPoint(x: c.x + sin(a) * outer, y: c.y - cos(a) * outer))
                let color: Color = isHour ? (dimmed ? Palette.dim : Palette.ink) : Palette.faint.opacity(dimmed ? 0.6 : 1.2)
                g.stroke(p, with: .color(color), lineWidth: isHour ? (i % 15 == 0 ? 3 : 2) : 1)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Analog") { FacePreview(style: .analog) }
