import SwiftUI

/// Opened with a long press. Three pages: Pokémon (Crown), Face (Crown), Settings.
struct CustomizeView: View {
    @State private var page = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                CompanionPicker().tag(0)
                FacePicker().tag(1)
                SettingsView().tag(2)
            }
            .tabViewStyle(.page)
            .background(Color.black)
        }
    }
}

/// Turn the Digital Crown through your favourites (or tap the arrows). Selection applies live.
/// "All Pokémon" opens the full, searchable grid.
struct CompanionPicker: View {
    @Environment(AppModel.self) private var model
    @State private var crown = 0.0
    @State private var roster: [CharacterDefinition] = []

    var body: some View {
        let list = roster.isEmpty ? [model.character] : roster
        let index = min(max(Int(crown.rounded()), 0), list.count - 1)
        let c = list[index]
        let art = ArtChoice(style: model.settings.spriteStyle, shiny: model.settings.shiny)

        TimelineView(.animation(minimumInterval: 1 / 12)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 86_400)
            VStack(spacing: 4) {
                Text("FAVOURITES")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Palette.dim)
                HStack {
                    StepButton(systemImage: "chevron.left") { crown = Double(max(0, index - 1)) }
                    Spacer(minLength: 0)
                    CompanionView(character: c,
                                  pose: CompanionAnimator.pose(c, AnimationInput(time: t, mood: .happy, animatedArt: true)),
                                  time: t, box: CGSize(width: 104, height: 76), art: art,
                                  particles: true, showSpeech: false)
                    Spacer(minLength: 0)
                    StepButton(systemImage: "chevron.right") { crown = Double(min(list.count - 1, index + 1)) }
                }
                Text(c.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(c.dexLabel) · \(art.style.shortTitle)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: c.accentHex))
                NavigationLink {
                    PokemonBrowser()
                } label: {
                    Text("All Pokémon")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.electric)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .overlay(Capsule().stroke(Palette.faint, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .focusable()
        .digitalCrownRotation($crown, from: 0, through: Double(max(list.count - 1, 0)), by: 1,
                              sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        .onAppear(perform: reload)
        .onChange(of: model.settings.characterID) { _, _ in if !roster.contains(where: { $0.id == model.settings.characterID }) { reload() } }
        .onChange(of: model.settings.favorites) { _, _ in reload() }
        .onChange(of: model.settings.spriteStyle) { _, _ in reload() }
        .onChange(of: index) { _, i in if list.indices.contains(i) { model.selectCharacter(list[i].id) } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pokémon: \(c.name)")
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: crown = Double(min(list.count - 1, index + 1))
            case .decrement: crown = Double(max(0, index - 1))
            @unknown default: break
            }
        }
    }

    private func reload() {
        roster = model.crownRoster
        crown = Double(roster.firstIndex { $0.id == model.settings.characterID } ?? 0)
    }
}

/// Browse watch faces with a live, scaled preview.
struct FacePicker: View {
    @Environment(AppModel.self) private var model
    @State private var crown = 0.0

    var body: some View {
        let faces = FaceStyle.allCases
        let index = min(max(Int(crown.rounded()), 0), faces.count - 1)
        let face = faces[index]

        GeometryReader { geo in
            VStack(spacing: 6) {
                Text("FACE \(face.number)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Palette.dim)
                FaceHost(style: face)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(0.56)
                    .frame(width: geo.size.width * 0.56, height: geo.size.height * 0.56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.faint, lineWidth: 1))
                    .allowsHitTesting(false)
                HStack {
                    StepButton(systemImage: "chevron.left") { crown = Double(max(0, index - 1)) }
                    Spacer(minLength: 0)
                    Text(face.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    StepButton(systemImage: "chevron.right") { crown = Double(min(faces.count - 1, index + 1)) }
                }
                PageDots(count: faces.count, index: index)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .focusable()
        .digitalCrownRotation($crown, from: 0, through: Double(faces.count - 1), by: 1,
                              sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        .onAppear { crown = Double(faces.firstIndex(of: model.settings.faceStyle) ?? 0) }
        .onChange(of: index) { _, i in model.settings.faceStyle = faces[i] }
    }
}

private struct StepButton: View {
    let systemImage: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.dim)
                .frame(width: 24, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }
}

private struct PageDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                Circle().fill(i == index ? Palette.electric : Palette.faint).frame(width: 4, height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}
