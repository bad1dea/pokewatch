import SwiftUI

/// 02 — Pokémon Yellow. Four-shade palette, pixel type, a companion walking a route,
/// and a battle-style text box with an HP (battery) bar.
struct YellowFace: View {
    let ctx: FaceContext
    var onTapCompanion: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let shades = ctx.options.retroPalette.shades.map(Color.init)
            let light = ctx.dimmed ? shades[2] : shades[0]
            let mid = ctx.dimmed ? shades[3] : shades[1]
            let dark = shades[3]
            let clock = ctx.clock
            let timeText = clock.hhmm
            let timePx = min(6, ((W - 56) / CGFloat(PixelFont.width(of: timeText))).rounded(.down))
            let spritePx: CGFloat = 3
            let walkRange = W * 0.26
            let travel = ctx.motionScale > 0 && !ctx.dimmed ? sin(ctx.time * 0.32) * walkRange : 0
            let facingLeft = ctx.motionScale > 0 && !ctx.dimmed && cos(ctx.time * 0.32) < 0
            let pose: CompanionPose = {
                var p = ctx.pose
                if facingLeft { p.flipped.toggle() }
                return p
            }()

            VStack(spacing: 0) {
                HStack {
                    if ctx.options.showDate {
                        PixelText(text: ClockFormatter.shortDate(ctx.date), pixel: 2, color: mid)
                    }
                    Spacer()
                }
                .frame(height: 16)

                HStack(alignment: .bottom, spacing: 6) {
                    PixelText(text: timeText, pixel: timePx, color: light)
                    VStack(alignment: .leading, spacing: 4) {
                        if let p = clock.period { PixelText(text: p, pixel: 2, color: mid) }
                        if ctx.showSeconds { PixelText(text: clock.second, pixel: 2, color: light) }
                    }
                }
                .padding(.top, 18)

                Spacer(minLength: 0)

                // The route: companion walks back and forth over tufts of grass.
                ZStack(alignment: .bottom) {
                    RouteTiles(time: ctx.dimmed ? 0 : ctx.time, color: dark, highlight: mid)
                        .frame(height: 14)
                    if ctx.showCompanion {
                        CompanionView(character: ctx.character, pose: pose, time: ctx.time, pixel: spritePx,
                                      tint: ctx.dimmed ? .shades(ctx.options.retroPalette.shades.map { $0.scaled(0.55) })
                                                       : .shades(ctx.options.retroPalette.shades),
                                      particles: false)
                            .companionTapTarget(onTapCompanion)
                            .offset(x: travel, y: -6)
                    }
                }
                .frame(height: CGFloat(ctx.character.height) * spritePx + 14)

                RetroTextBox(ctx: ctx, light: light, mid: mid, dark: dark)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .frame(width: W, height: H)
        }
    }
}

/// Repeating grass tufts that scroll slowly.
private struct RouteTiles: View {
    let time: TimeInterval
    let color: Color
    let highlight: Color

    var body: some View {
        Canvas { g, size in
            let p: CGFloat = 2
            let tile: CGFloat = 16
            let shift = CGFloat((time * 3).truncatingRemainder(dividingBy: Double(tile)))
            var x = -tile + shift
            var i = 0
            while x < size.width + tile {
                let base = size.height - p
                // ground dots
                g.fill(Path(CGRect(x: x, y: base, width: p, height: p)), with: .color(color))
                g.fill(Path(CGRect(x: x + 8, y: base, width: p, height: p)), with: .color(color))
                if i % 3 == 0 {
                    // tuft: ┘└ shape
                    for (dx, dy) in [(4, -2), (6, -4), (8, -2), (6, -2), (2, 0), (10, 0)] {
                        g.fill(Path(CGRect(x: x + CGFloat(dx), y: base + CGFloat(dy) * p / 2, width: p, height: p)),
                               with: .color(highlight.opacity(0.55)))
                    }
                }
                x += tile; i += 1
            }
        }
        .accessibilityHidden(true)
    }
}

/// Battle-style text box: name + level, HP bar (battery), step count.
private struct RetroTextBox: View {
    let ctx: FaceContext
    let light: Color
    let mid: Color
    let dark: Color

    var body: some View {
        let level = 5 + min(95, (ctx.activity.steps ?? 0) / 500)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                PixelText(text: ctx.character.name, pixel: 2, color: light)
                Spacer()
                PixelText(text: "LV\(level)", pixel: 2, color: mid)
            }
            if ctx.options.showBattery {
                HStack(spacing: 5) {
                    PixelText(text: "HP", pixel: 2, color: mid)
                    PixelBar(value: ctx.battery.level ?? 0, segments: 12, color: ctx.battery.isLow ? Palette.lowRed : light, track: dark)
                    PixelText(text: ctx.battery.percentText, pixel: 1.5, color: mid)
                }
            }
            if ctx.options.showActivity {
                HStack(spacing: 5) {
                    PixelText(text: "EXP", pixel: 2, color: mid)
                    PixelBar(value: min(1, ctx.stepProgress ?? 0), segments: 12, color: light, track: dark)
                    PixelText(text: ctx.activity.steps.map { "\($0)" } ?? "--", pixel: 1.5, color: mid)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .overlay(
            ZStack {
                Rectangle().stroke(mid, lineWidth: 2)
                Rectangle().inset(by: 3).stroke(dark, lineWidth: 1)
            }
        )
    }
}

/// Segmented bar drawn in whole pixels.
struct PixelBar: View {
    let value: Double
    var segments = 10
    var color: Color
    var track: Color

    var body: some View {
        Canvas { g, size in
            let gap: CGFloat = 1
            let w = (size.width - gap * CGFloat(segments - 1)) / CGFloat(segments)
            let lit = Int((max(0, min(1, value)) * Double(segments)).rounded(.up))
            for i in 0..<segments {
                let r = CGRect(x: CGFloat(i) * (w + gap), y: 0, width: w, height: size.height)
                g.fill(Path(r), with: .color(i < lit ? color : track))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

#Preview("Yellow") { FacePreview(style: .yellow) }
