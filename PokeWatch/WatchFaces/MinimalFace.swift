import SwiftUI

/// 03 — Minimal. Thin oversized time, one quiet line of data, a small silhouette.
struct MinimalFace: View {
    let ctx: FaceContext
    var onTapCompanion: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            let f = FaceFrame(size: geo.size)
            ZStack(alignment: .topLeading) {
                clockBlock(f)
                    .frame(width: f.W - 30, alignment: .leading)
                    .offset(x: 15, y: f.H * 0.16)
                bottomRow(f)
            }
            .frame(width: f.W, height: f.H, alignment: .topLeading)
        }
    }

    private func clockBlock(_ f: FaceFrame) -> some View {
        let clock = ctx.clock
        let timeSize = min(f.W * 0.34, f.H * 0.29)
        let accent = ctx.dimmed ? Palette.faint : ctx.accent
        return VStack(alignment: .leading, spacing: 0) {
            if ctx.options.showDate {
                Text("\(ClockFormatter.weekday(ctx.date)) \(ClockFormatter.day(ctx.date))")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(ctx.dimmed ? Palette.faint : Palette.dim)
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(clock.hour)
                Text(":").foregroundStyle(accent)
                Text(clock.minute)
            }
            .font(.system(size: timeSize, weight: .thin))
            .monospacedDigit()
            .foregroundStyle(ctx.dimmed ? Palette.dim : Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.leading, -2)
            HStack(spacing: 8) {
                if let p = clock.period { Text(p).foregroundStyle(ctx.dimmed ? Palette.faint : Palette.dim) }
                if ctx.showSeconds { Text(clock.second).foregroundStyle(accent).monospacedDigit() }
            }
            .font(.system(size: 13, weight: .medium))
        }
    }

    private func bottomRow(_ f: FaceFrame) -> some View {
        let top = f.H - 60, bottom = f.H - 12
        let side = f.inset(bottom - 14, bottom)
        let base = RGB(hex: ctx.options.accent.hex) ?? RGB(r: 255, g: 225, b: 0)
        let silhouette: SpriteTint = .silhouette(ctx.dimmed ? base.scaled(0.3) : base)
        return HStack(alignment: .bottom) {
            Text(statusLine)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(ctx.dimmed ? Palette.faint : Palette.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            if ctx.showCompanion {
                CompanionView(character: ctx.character, pose: ctx.pose, time: ctx.time,
                              box: CGSize(width: 56, height: bottom - top), art: ctx.art,
                              tint: silhouette, particles: false, showSpeech: false)
                    .companionTapTarget(onTapCompanion)
            }
        }
        .frame(width: f.W - side * 2, height: bottom - top, alignment: .bottom)
        .offset(x: side, y: top)
    }

    private var statusLine: String {
        var parts: [String] = []
        if ctx.options.showBattery { parts.append(ctx.battery.percentText) }
        if ctx.options.showActivity, let s = ctx.activity.steps { parts.append("\(s.compactSteps) steps") }
        return parts.joined(separator: " · ")
    }
}

#Preview("Minimal") { FacePreview(style: .minimal) }
