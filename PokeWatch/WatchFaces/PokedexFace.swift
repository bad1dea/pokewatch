import SwiftUI

/// 05 — Pokédex. Retro-futuristic instrument layout: entry header, specimen viewport,
/// clock, and a block of readouts. Red and yellow are used only as indicators.
struct PokedexFace: View {
    let ctx: FaceContext
    var onTapCompanion: () -> Void = {}

    private let red = Color(hex: "#E8433A")
    private let mono = Font.system(size: 11, weight: .medium, design: .monospaced)

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let c = ctx.character
            let ink = ctx.dimmed ? Palette.dim : Palette.ink
            let px: CGFloat = max(2, ((W * 0.44 - 10) / CGFloat(c.width)).rounded(.down))
            let viewport = CGSize(width: CGFloat(c.width) * px + 10, height: CGFloat(c.height) * px + 12)

            VStack(alignment: .leading, spacing: 0) {
                // Header: lens + entry number.
                HStack(spacing: 6) {
                    ZStack {
                        Circle().fill(ctx.dimmed ? Palette.faint : red)
                        Circle().stroke(Palette.dim, lineWidth: 1)
                        Circle().fill(.white.opacity(ctx.dimmed ? 0 : 0.7)).frame(width: 3, height: 3).offset(x: -2, y: -2)
                    }
                    .frame(width: 13, height: 13)
                    Circle().fill(ctx.dimmed ? Palette.faint : Palette.electric).frame(width: 4, height: 4)
                    Text(c.dexLabel).font(mono).foregroundStyle(ctx.dimmed ? Palette.faint : Palette.dim)
                }
                .frame(height: 18)

                Text(c.name.uppercased())
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(c.category.uppercased()) · \(c.type.uppercased())")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(ctx.dimmed ? Palette.faint : Palette.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(alignment: .center, spacing: 8) {
                    // Specimen viewport.
                    ZStack {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(ctx.dimmed ? Palette.faint : red.opacity(0.85), lineWidth: 1.5)
                        ScanLines().stroke(Color.white.opacity(ctx.dimmed ? 0 : 0.05), lineWidth: 1)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        if ctx.showCompanion {
                            CompanionView(character: c, pose: ctx.pose, time: ctx.time, pixel: px,
                                          tint: ctx.spriteTint(), particles: false, showSpeech: false)
                                .companionTapTarget(onTapCompanion)
                        }
                    }
                    .frame(width: viewport.width, height: viewport.height)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(ctx.clock.hhmm)
                            .font(.system(size: min(36, W * 0.17), weight: .semibold, design: .monospaced))
                            .foregroundStyle(ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        HStack(spacing: 6) {
                            if ctx.showSeconds {
                                Text(ctx.clock.second).foregroundStyle(ctx.accent)
                            }
                            if let p = ctx.clock.period { Text(p).foregroundStyle(Palette.dim) }
                        }
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        if ctx.options.showDate {
                            Text(ClockFormatter.longDate(ctx.date))
                                .font(mono)
                                .foregroundStyle(ctx.dimmed ? Palette.faint : Palette.dim)
                        }
                        Text(ctx.mood.label.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(ctx.dimmed ? Palette.faint : ctx.accent)
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 8)

                Spacer(minLength: 6)

                VStack(spacing: 5) {
                    if ctx.options.showBattery {
                        Readout(label: "BAT", value: ctx.battery.level, text: ctx.battery.percentText,
                                color: ctx.battery.isLow ? Palette.lowRed : ctx.accent, dimmed: ctx.dimmed)
                    }
                    if ctx.options.showActivity {
                        Readout(label: "STP", value: ctx.stepProgress,
                                text: ctx.activity.steps.map { "\($0)" } ?? "--", color: ctx.accent, dimmed: ctx.dimmed)
                        Readout(label: "CAL", value: ctx.activity.moveProgress,
                                text: ctx.activity.activeEnergy.map { "\(Int($0))" } ?? "--", color: red, dimmed: ctx.dimmed)
                        Readout(label: "EXR", value: ctx.activity.exerciseProgress,
                                text: ctx.activity.exerciseMinutes.map { "\(Int($0))m" } ?? "--", color: Palette.ink, dimmed: ctx.dimmed)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 10)
            .frame(width: W, height: H, alignment: .topLeading)
        }
    }
}

private struct Readout: View {
    let label: String
    let value: Double?
    let text: String
    let color: Color
    let dimmed: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(dimmed ? Palette.faint : Palette.dim)
                .frame(width: 26, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Palette.faint.opacity(0.7))
                    Rectangle().fill(dimmed ? Palette.dim : color)
                        .frame(width: g.size.width * min(1, max(0, value ?? 0)))
                }
            }
            .frame(height: 3)
            Text(text)
                .foregroundStyle(dimmed ? Palette.dim : Palette.ink)
                .frame(width: 44, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(text)")
    }
}

private struct ScanLines: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var y = rect.minY + 2
        while y < rect.maxY {
            p.move(to: CGPoint(x: rect.minX, y: y)); p.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += 3
        }
        return p
    }
}

#Preview("Pokédex") { FacePreview(style: .pokedex) }
