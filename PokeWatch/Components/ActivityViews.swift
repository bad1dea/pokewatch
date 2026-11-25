import SwiftUI

/// Thin step progress bar with count.
struct StepMeter: View {
    let steps: Int?
    let goal: Int
    var accent: Color = Palette.electric
    var dimmed = false
    var width: CGFloat = 70
    var font: Font = .system(size: 13, weight: .semibold, design: .rounded)

    var body: some View {
        let progress = steps.map { min(1, Double($0) / Double(max(goal, 1))) } ?? 0
        VStack(alignment: .trailing, spacing: 3) {
            Text(steps.map { $0.compactSteps } ?? "--")
                .font(font)
                .monospacedDigit()
                .foregroundStyle(dimmed ? Palette.dim : Palette.ink)
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.faint)
                Capsule().fill(dimmed ? Palette.dim : accent).frame(width: width * progress)
            }
            .frame(width: width, height: 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(steps.map { "\($0) of \(goal) steps" } ?? "Steps unavailable")
    }
}

/// Three concentric arcs for move / exercise / stand, in restrained tones.
struct MiniRings: View {
    let activity: ActivitySnapshot
    var size: CGFloat = 26
    var dimmed = false

    var body: some View {
        let colors: [Color] = dimmed
            ? [Palette.dim, Palette.dim.opacity(0.8), Palette.dim.opacity(0.6)]
            : [Color(hex: "#FF4F6A"), Color(hex: "#B6F34A"), Color(hex: "#5FE3F0")]
        let values = [activity.moveProgress, activity.exerciseProgress, activity.standProgress]
        let lw = size * 0.11
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let inset = CGFloat(i) * (lw + 1.5)
                Circle().inset(by: inset + lw / 2).stroke(colors[i].opacity(0.22), lineWidth: lw)
                Circle().inset(by: inset + lw / 2)
                    .trim(from: 0, to: min(1, values[i] ?? 0))
                    .stroke(colors[i], style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Activity rings")
    }
}
