import SwiftUI

/// 02 — Pokémon Yellow. Four-shade palette, pixel type, Gen I art walking a route,
/// and a battle-style text box with an HP (battery) bar.
struct YellowFace: View {
    let ctx: FaceContext
    var onTapCompanion: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            let f = FaceFrame(size: geo.size)
            let palette = ctx.options.retroPalette.shades
            let shades = palette.map(Color.init)
            let light = ctx.dimmed ? shades[2] : shades[0]
            let mid = ctx.dimmed ? shades[3] : shades[1]
            let dark = shades[3]
            let clock = ctx.clock
            let timeText = clock.hhmm
            let timePx = min(5, ((f.W - 70) / CGFloat(PixelFont.width(of: timeText))).rounded(.down))
            let timeTop: CGFloat = 34
            let box: (CGFloat, CGFloat) = (f.H - 78, f.H - 21)
            let routeTop = timeTop + CGFloat(PixelFont.height) * timePx + 6
            let routeBox = CGSize(width: f.W - 24, height: box.0 - 6 - routeTop)
            let walk = ctx.motionScale > 0 && !ctx.dimmed
            let travel = walk ? sin(ctx.time * 0.32) * (f.W * 0.22) : 0
            let pose: CompanionPose = {
                var p = ctx.pose
                if walk && cos(ctx.time * 0.32) < 0 { p.flipped.toggle() }
                return p
            }()
            let tintShades = ctx.dimmed ? palette.map { $0.scaled(0.55) } : palette

            ZStack(alignment: .topLeading) {
                if ctx.options.showDate {
                    PixelText(text: ClockFormatter.shortDate(ctx.date), pixel: 2, color: mid)
                        .offset(x: f.inset(10, 24), y: 10)
                }

                HStack(alignment: .bottom, spacing: 6) {
                    PixelText(text: timeText, pixel: timePx, color: light)
                    VStack(alignment: .leading, spacing: 4) {
                        if let p = clock.period { PixelText(text: p, pixel: 2, color: mid) }
                        if ctx.showSeconds { PixelText(text: clock.second, pixel: 2, color: light) }
                    }
                }
                .offset(x: 14, y: timeTop)

                ZStack(alignment: .bottom) {
                    RouteTiles(time: ctx.dimmed ? 0 : ctx.time, color: dark, highlight: mid)
                        .frame(height: 12)
                    if ctx.showCompanion {
                        CompanionView(character: ctx.character, pose: pose, time: ctx.time,
                                      box: CGSize(width: routeBox.width * 0.5, height: routeBox.height - 6),
                                      art: ArtChoice(style: .gen1, shiny: ctx.art.shiny),
                                      tint: .shades(tintShades), particles: false)
                            .companionTapTarget(onTapCompanion)
                            .offset(x: travel, y: -6)
                    }
                }
                .frame(width: routeBox.width, height: routeBox.height)
                .offset(x: 12, y: routeTop)

                // +4: the border stroke draws outside the frame, and its corners are the widest point.
                let side = f.inset(box.0, box.1 + 4)
                RetroTextBox(ctx: ctx, light: light, mid: mid, dark: dark)
                    .frame(width: f.W - side * 2, height: box.1 - box.0)
                    .offset(x: side, y: box.0)
            }
            .frame(width: f.W, height: f.H, alignment: .topLeading)
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
                g.fill(Path(CGRect(x: x, y: base, width: p, height: p)), with: .color(color))
                g.fill(Path(CGRect(x: x + 8, y: base, width: p, height: p)), with: .color(color))
                if i % 3 == 0 {
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

/// Battle-style text box: name + level, HP bar (battery), EXP bar (steps).
private struct RetroTextBox: View {
    let ctx: FaceContext
    let light: Color
    let mid: Color
    let dark: Color

    var body: some View {
        let level = 5 + min(95, (ctx.activity.steps ?? 0) / 500)
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                PixelText(text: String(ctx.character.name.prefix(10)), pixel: 2, color: light)
                Spacer(minLength: 4)
                PixelText(text: "LV\(level)", pixel: 2, color: mid)
            }
            if ctx.options.showBattery {
                HStack(spacing: 4) {
                    PixelText(text: "HP", pixel: 2, color: mid)
                    PixelBar(value: ctx.battery.level ?? 0, segments: 10, color: ctx.battery.isLow ? Palette.lowRed : light, track: dark)
                    PixelText(text: ctx.battery.percentText, pixel: 1.5, color: mid)
                }
            }
            if ctx.options.showActivity {
                HStack(spacing: 4) {
                    PixelText(text: "EXP", pixel: 2, color: mid)
                    PixelBar(value: min(1, ctx.stepProgress ?? 0), segments: 10, color: light, track: dark)
                    PixelText(text: ctx.activity.steps.map { "\($0)" } ?? "--", pixel: 1.5, color: mid)
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
