import SwiftUI

/// 01 — Electric. Big rounded clock, the companion centre stage, sparks, Pokéball battery.
struct ElectricFace: View {
    let ctx: FaceContext
    var onTapCompanion: () -> Void = {}

    private struct Bands {
        let timeSize: CGFloat
        let timeTop: CGFloat = 30
        let spriteTop: CGFloat
        let spriteBox: CGSize
        let bottomTop: CGFloat
        let bottomBottom: CGFloat

        init(_ f: FaceFrame) {
            timeSize = min(f.W * 0.27, f.H * 0.23)
            bottomTop = f.H - 30
            bottomBottom = f.H - 12
            spriteTop = 30 + timeSize * 1.05 + 2
            spriteBox = CGSize(width: f.W - 24, height: max(60, bottomTop - 4 - spriteTop))
        }
    }

    var body: some View {
        GeometryReader { geo in
            let f = FaceFrame(size: geo.size)
            let b = Bands(f)
            ZStack(alignment: .topLeading) {
                if ctx.particlesEnabled && !ctx.dimmed {
                    ParticleField(element: .spark, time: ctx.time * 0.8, level: 0.35, pixel: 2, color: ctx.accent.opacity(0.7))
                        .frame(width: f.W - 40, height: b.spriteBox.height)
                        .offset(x: 20, y: b.spriteTop)
                }
                if ctx.options.showDate {
                    // Top-left, clear of the corner and of the system time on the right.
                    Text(ClockFormatter.shortDate(ctx.date))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .offset(x: f.inset(10, 26), y: 10)
                }
                time(b)
                    .frame(width: f.W - 24, alignment: .leading)
                    .offset(x: 12, y: b.timeTop)
                if ctx.showCompanion {
                    CompanionView(character: ctx.character, pose: ctx.pose, time: ctx.time, box: b.spriteBox,
                                  art: ctx.art, tint: ctx.spriteTint(), particles: ctx.particlesEnabled && !ctx.dimmed)
                        .companionTapTarget(onTapCompanion)
                        .offset(x: 12, y: b.spriteTop)
                }
                bottomRow(f, b)
            }
            .frame(width: f.W, height: f.H, alignment: .topLeading)
        }
    }

    private var accent: Color { ctx.dimmed ? Palette.eveningDim : ctx.accent }

    private func time(_ b: Bands) -> some View {
        let clock = ctx.clock
        let ink = ctx.dimmed ? Palette.dim : Palette.ink
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(clock.hour).foregroundStyle(ink)
            Text(":").foregroundStyle(accent).padding(.horizontal, 1)
            Text(clock.minute).foregroundStyle(ink)
            VStack(alignment: .leading, spacing: 0) {
                if let period = clock.period {
                    Text(period)
                        .font(.system(size: b.timeSize * 0.22, weight: .bold, design: .rounded))
                        .foregroundStyle(ctx.dimmed ? Palette.faint : Palette.dim)
                }
                if ctx.showSeconds {
                    Text(clock.second)
                        .font(.system(size: b.timeSize * 0.3, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .monospacedDigit()
                }
            }
            .padding(.leading, 3)
        }
        .font(.system(size: b.timeSize, weight: ctx.dimmed ? .semibold : .heavy, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private func bottomRow(_ f: FaceFrame, _ b: Bands) -> some View {
        let side = f.inset(b.bottomTop, b.bottomBottom)
        return HStack(alignment: .bottom) {
            if ctx.options.showBattery {
                PokeballBattery(battery: ctx.battery, accent: ctx.accent, dimmed: ctx.dimmed, size: 14,
                                font: .system(size: 12, weight: .semibold, design: .rounded))
            }
            Spacer(minLength: 0)
            if ctx.options.showActivity {
                StepMeter(steps: ctx.activity.steps, goal: ctx.options.stepGoal, accent: ctx.accent,
                          dimmed: ctx.dimmed, width: 56, font: .system(size: 12, weight: .semibold, design: .rounded))
            }
        }
        .frame(width: f.W - side * 2, height: b.bottomBottom - b.bottomTop, alignment: .bottom)
        .offset(x: side, y: b.bottomTop)
    }
}

#Preview("Electric") { FacePreview(style: .electric) }
#Preview("Electric AOD") { FacePreview(style: .electric, dimmed: true) }
