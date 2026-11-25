import SwiftUI

/// 03 — Minimal. Thin oversized time, one quiet line of data, a small silhouette.
/// Office-appropriate: almost every pixel stays black.
struct MinimalFace: View {
    let ctx: FaceContext
    var onTapCompanion: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let clock = ctx.clock
            let timeSize = min(W * 0.36, H * 0.3)
            let ink = ctx.dimmed ? Palette.dim : Palette.ink
            let accent = ctx.dimmed ? Palette.faint : ctx.accent

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: H * 0.12)

                if ctx.options.showDate {
                    Text(dateLine)
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
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.leading, -3)

                HStack(spacing: 8) {
                    if let p = clock.period {
                        Text(p).foregroundStyle(ctx.dimmed ? Palette.faint : Palette.dim)
                    }
                    if ctx.showSeconds {
                        Text(clock.second).foregroundStyle(accent).monospacedDigit()
                    }
                }
                .font(.system(size: 13, weight: .medium))

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    Text(statusLine)
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(ctx.dimmed ? Palette.faint : Palette.dim)
                    Spacer()
                    if ctx.showCompanion {
                        CompanionView(character: ctx.character, pose: ctx.pose, time: ctx.time, pixel: 2,
                                      tint: ctx.dimmed ? .silhouette(RGB(hex: ctx.options.accent.hex)!.scaled(0.3))
                                                       : .silhouette(RGB(hex: ctx.options.accent.hex)!),
                                      particles: false, showSpeech: false)
                            .companionTapTarget(onTapCompanion)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .frame(width: W, height: H, alignment: .topLeading)
        }
    }

    private var dateLine: String {
        "\(ClockFormatter.weekday(ctx.date)) \(ClockFormatter.day(ctx.date))"
    }

    private var statusLine: String {
        var parts: [String] = []
        if ctx.options.showBattery { parts.append(ctx.battery.percentText) }
        if ctx.options.showActivity, let s = ctx.activity.steps { parts.append("\(s.compactSteps) steps") }
        return parts.joined(separator: "  ·  ")
    }
}

#Preview("Minimal") { FacePreview(style: .minimal) }
