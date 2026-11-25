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
            let f = FaceFrame(size: geo.size)
            let rows: CGFloat = ctx.options.showActivity ? 4 : (ctx.options.showBattery ? 1 : 0)
            let readoutTop = f.H - 14 - rows * 14
            ZStack(alignment: .topLeading) {
                header.offset(x: f.inset(9, 23), y: 9)
                title(f).offset(x: 14, y: 26)
                specimen(f, readoutTop: readoutTop).offset(x: 13, y: 60)
                readouts(f, top: readoutTop)
            }
            .frame(width: f.W, height: f.H, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(ctx.dimmed ? Palette.faint : red)
                Circle().stroke(Palette.dim, lineWidth: 1)
                Circle().fill(.white.opacity(ctx.dimmed ? 0 : 0.7)).frame(width: 3, height: 3).offset(x: -2, y: -2)
            }
            .frame(width: 12, height: 12)
            Circle().fill(ctx.dimmed ? Palette.faint : Palette.electric).frame(width: 4, height: 4)
            Text(ctx.character.dexLabel).font(mono).foregroundStyle(ctx.dimmed ? Palette.faint : Palette.dim)
        }
    }

    private func title(_ f: FaceFrame) -> some View {
        let c = ctx.character
        return VStack(alignment: .leading, spacing: 0) {
            Text(c.name.uppercased())
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(ctx.dimmed ? Palette.dim : Palette.ink)
            Text("\(c.category.uppercased()) · \(c.type.uppercased())")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(ctx.dimmed ? Palette.faint : Palette.dim)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(width: f.W - 28 - 70, alignment: .leading)
    }

    private func specimen(_ f: FaceFrame, readoutTop: CGFloat) -> some View {
        let viewport = CGSize(width: f.W * 0.44, height: min(f.W * 0.4, readoutTop - 70))
        return HStack(alignment: .center, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(ctx.dimmed ? Palette.faint : red.opacity(0.85), lineWidth: 1.5)
                ScanLines().stroke(Color.white.opacity(ctx.dimmed ? 0 : 0.05), lineWidth: 1)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                if ctx.showCompanion {
                    CompanionView(character: ctx.character, pose: ctx.pose, time: ctx.time,
                                  box: CGSize(width: viewport.width - 8, height: viewport.height - 6),
                                  art: ctx.art, tint: ctx.spriteTint(), particles: false, showSpeech: false,
                                  fill: 0.92)
                        .companionTapTarget(onTapCompanion)
                }
            }
            .frame(width: viewport.width, height: viewport.height)
            clockColumn(f)
        }
        .frame(width: f.W - 26)
    }

    private func clockColumn(_ f: FaceFrame) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ctx.clock.hhmm)
                .font(.system(size: min(34, f.W * 0.16), weight: .semibold, design: .monospaced))
                .foregroundStyle(ctx.dimmed ? Palette.dim : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            HStack(spacing: 6) {
                if ctx.showSeconds { Text(ctx.clock.second).foregroundStyle(ctx.accent) }
                if let p = ctx.clock.period { Text(p).foregroundStyle(Palette.dim) }
            }
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            if ctx.options.showDate {
                Text(ClockFormatter.longDate(ctx.date))
                    .font(mono)
                    .foregroundStyle(ctx.dimmed ? Palette.faint : Palette.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(ctx.mood.label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(ctx.dimmed ? Palette.faint : ctx.accent)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func readouts(_ f: FaceFrame, top: CGFloat) -> some View {
        let bottom = f.H - 14
        let side = f.inset(top, bottom)
        let a = ctx.activity
        return VStack(spacing: 3) {
            if ctx.options.showBattery {
                Readout(label: "BAT", value: ctx.battery.level, text: ctx.battery.percentText,
                        color: ctx.battery.isLow ? Palette.lowRed : ctx.accent, dimmed: ctx.dimmed)
            }
            if ctx.options.showActivity {
                Readout(label: "STP", value: ctx.stepProgress, text: a.steps.map { "\($0)" } ?? "--",
                        color: ctx.accent, dimmed: ctx.dimmed)
                Readout(label: "CAL", value: a.moveProgress, text: a.activeEnergy.map { "\(Int($0))" } ?? "--",
                        color: red, dimmed: ctx.dimmed)
                Readout(label: "EXR", value: a.exerciseProgress, text: a.exerciseMinutes.map { "\(Int($0))m" } ?? "--",
                        color: Palette.ink, dimmed: ctx.dimmed)
            }
        }
        .frame(width: f.W - side * 2, height: bottom - top, alignment: .bottom)
        .offset(x: side, y: top)
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
                .frame(width: 24, alignment: .leading)
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
                .frame(width: 38, alignment: .trailing)
        }
        .frame(height: 11)
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
