import SwiftUI

/// 04 — Sleeping. Evening palette, the companion asleep at the bottom of the screen,
/// breathing and flicking an ear. Designed to look almost the same in Always-On.
struct SleepingFace: View {
    let ctx: FaceContext
    var onTapCompanion: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let clock = ctx.clock
            let tone = ctx.dimmed ? Palette.eveningDim : Palette.evening
            let px = max(4, (min(W / 211, H / 257) * 5).rounded(.down))
            let spriteW = CGFloat(ctx.character.width) * px

            ZStack(alignment: .topLeading) {
                Crescent()
                    .fill(ctx.dimmed ? Palette.faint : Palette.eveningDim)
                    .frame(width: 18, height: 18)
                    .position(x: 22, y: 22)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(clock.hhmm)
                            .font(.system(size: min(W * 0.24, 54), weight: .medium, design: .rounded))
                            .monospacedDigit()
                        if let p = clock.period {
                            Text(p).font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(ctx.dimmed ? Palette.faint : Palette.eveningDim)
                        }
                        if ctx.showSeconds {
                            Text(clock.second).font(.system(size: 13, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Palette.eveningDim)
                        }
                    }
                    .foregroundStyle(tone)
                    if ctx.options.showDate {
                        Text(ClockFormatter.longDate(ctx.date))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(ctx.dimmed ? Palette.faint : Palette.eveningDim)
                    }
                    HStack(spacing: 10) {
                        if ctx.options.showBattery {
                            PokeballBattery(battery: ctx.battery, accent: Palette.evening, dimmed: true, size: 12,
                                            font: .system(size: 11, weight: .semibold, design: .rounded))
                        }
                        if ctx.options.showActivity, let s = ctx.activity.steps {
                            Text("\(s.compactSteps) steps")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.dim)
                        }
                    }
                    .padding(.top, 4)
                    .opacity(ctx.dimmed ? 0.6 : 1)
                }
                .padding(.leading, 14)
                .padding(.top, 40)

                if ctx.showCompanion {
                    VStack(spacing: 0) {
                        CompanionView(character: ctx.character, pose: ctx.pose, time: ctx.time, pixel: px,
                                      tint: ctx.dimmed ? .dimmed(38) : .dimmed(72),
                                      particles: ctx.particlesEnabled && !ctx.dimmed,
                                      particleColor: Color(hex: "#9AA6D6"))
                            .companionTapTarget(onTapCompanion)
                        // A soft cushion line, not a card.
                        Capsule()
                            .fill(Color(hex: ctx.dimmed ? "#141824" : "#1E2436"))
                            .frame(width: spriteW * 1.05, height: 5)
                            .padding(.top, -2)
                    }
                    .frame(width: W)
                    .position(x: W / 2, y: H - CGFloat(ctx.character.height) * px / 2 - 8)
                }
            }
            .frame(width: W, height: H)
        }
    }
}

private struct Crescent: Shape {
    func path(in rect: CGRect) -> Path {
        let outer = Path(ellipseIn: rect)
        let inner = Path(ellipseIn: rect.offsetBy(dx: rect.width * 0.32, dy: -rect.height * 0.12))
        return outer.subtracting(inner)
    }
}

#Preview("Sleeping") { FacePreview(style: .sleeping) }
