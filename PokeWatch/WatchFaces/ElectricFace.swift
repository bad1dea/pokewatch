import SwiftUI

/// 01 — Electric. Big rounded clock, Pikachu-forward, sparks, Pokéball battery.
struct ElectricFace: View {
    let ctx: FaceContext
    var onTapCompanion: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let px = max(3, (min(W / 211, H / 257) * 4).rounded(.down))
            let timeSize = min(W * 0.28, H * 0.24)
            let clock = ctx.clock
            let ink = ctx.dimmed ? Palette.dim : Palette.ink
            let accent = ctx.dimmed ? Palette.eveningDim : ctx.accent

            ZStack {
                if ctx.particlesEnabled && !ctx.dimmed {
                    ParticleField(element: .spark, time: ctx.time * 0.8, level: 0.35, pixel: 2, color: ctx.accent.opacity(0.7))
                        .frame(width: W, height: H * 0.7)
                        .position(x: W / 2, y: H * 0.6)
                }

                VStack(alignment: .leading, spacing: 0) {
                    // Date sits top-left; the top-right corner belongs to the system time.
                    Text(ctx.options.showDate ? ClockFormatter.shortDate(ctx.date) : " ")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .padding(.top, 2)

                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(clock.hour).foregroundStyle(ink)
                        Text(":").foregroundStyle(accent).padding(.horizontal, 1)
                        Text(clock.minute).foregroundStyle(ink)
                        VStack(alignment: .leading, spacing: 0) {
                            if let period = clock.period {
                                Text(period)
                                    .font(.system(size: timeSize * 0.22, weight: .bold, design: .rounded))
                                    .foregroundStyle(ctx.dimmed ? Palette.faint : Palette.dim)
                            }
                            if ctx.showSeconds {
                                Text(clock.second)
                                    .font(.system(size: timeSize * 0.3, weight: .bold, design: .rounded))
                                    .foregroundStyle(accent)
                                    .monospacedDigit()
                            }
                        }
                        .padding(.leading, 3)
                    }
                    .font(.system(size: timeSize, weight: ctx.dimmed ? .semibold : .heavy, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 10)

                    Spacer(minLength: 0)

                    if ctx.showCompanion {
                        CompanionView(character: ctx.character, pose: ctx.pose, time: ctx.time, pixel: px,
                                      tint: ctx.spriteTint(), particles: ctx.particlesEnabled && !ctx.dimmed)
                            .companionTapTarget(onTapCompanion)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 6)
                    }

                    HStack(alignment: .bottom) {
                        if ctx.options.showBattery {
                            PokeballBattery(battery: ctx.battery, accent: ctx.accent, dimmed: ctx.dimmed)
                        }
                        Spacer(minLength: 0)
                        if ctx.options.showActivity {
                            StepMeter(steps: ctx.activity.steps, goal: ctx.options.stepGoal,
                                      accent: ctx.accent, dimmed: ctx.dimmed, width: 64)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
        }
    }
}

#Preview("Electric") { FacePreview(style: .electric) }
#Preview("Electric AOD") { FacePreview(style: .electric, dimmed: true) }
