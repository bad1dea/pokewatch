import SwiftUI

/// 04 — Sleeping. Evening palette, the companion asleep at the bottom of the screen,
/// breathing quietly. Designed to look almost the same in Always-On.
struct SleepingFace: View {
    let ctx: FaceContext
    var onTapCompanion: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            let f = FaceFrame(size: geo.size)
            let clock = ctx.clock
            let tone = ctx.dimmed ? Palette.eveningDim : Palette.evening
            let spriteBottom = f.H - 16
            let spriteBox = CGSize(width: f.W - 2 * f.inset(spriteBottom - 30, spriteBottom), height: f.H * 0.44)

            ZStack(alignment: .topLeading) {
                Crescent()
                    .fill(ctx.dimmed ? Palette.faint : Palette.eveningDim)
                    .frame(width: 15, height: 15)
                    .offset(x: f.inset(10, 25), y: 10)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(clock.hhmm)
                            .font(.system(size: min(f.W * 0.23, 50), weight: .medium, design: .rounded))
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
                    .padding(.top, 3)
                    .opacity(ctx.dimmed ? 0.6 : 1)
                }
                .frame(width: f.W - 30, alignment: .leading)
                .offset(x: 15, y: 32)

                if ctx.showCompanion {
                    VStack(spacing: 0) {
                        CompanionView(character: ctx.character, pose: ctx.pose, time: ctx.time, box: spriteBox,
                                      art: ctx.art, tint: ctx.dimmed ? .dimmed(40) : .dimmed(75),
                                      particles: ctx.particlesEnabled && !ctx.dimmed,
                                      particleColor: Color(hex: "#9AA6D6"), fill: 0.9)
                            .companionTapTarget(onTapCompanion)
                        Capsule()
                            .fill(Color(hex: ctx.dimmed ? "#141824" : "#1E2436"))
                            .frame(width: spriteBox.width * 0.7, height: 4)
                    }
                    .frame(width: f.W)
                    .offset(y: spriteBottom - spriteBox.height)
                }
            }
            .frame(width: f.W, height: f.H, alignment: .topLeading)
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
