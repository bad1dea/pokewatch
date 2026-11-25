import SwiftUI

/// All six faces, live, with the current Pokémon. Tap to use one; colours below.
struct FacesScreen: View {
    @Environment(PhoneModel.self) private var model

    var body: some View {
        GeometryReader { geo in
            let columns = geo.size.width < 380 ? 2 : (geo.size.width < 640 ? 3 : (geo.size.width < 1000 ? 4 : 6))
            let spacing: CGFloat = 14
            let cell = (geo.size.width - 32 - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: spacing), count: columns),
                              spacing: 18) {
                        ForEach(FaceStyle.allCases) { face in
                            faceCell(face, width: cell - 20)
                        }
                    }
                    look
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.black)
        .navigationTitle("Faces")
    }

    private func faceCell(_ face: FaceStyle, width: CGFloat) -> some View {
        let selected = model.settings.faceStyle == face
        return Button { model.settings.faceStyle = face } label: {
            VStack(spacing: 8) {
                WatchFacePreview(face: face, width: width, animate: selected)
                Text(face.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(selected ? Palette.electric : Palette.ink)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18).stroke(selected ? Palette.electric : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var look: some View {
        @Bindable var s = model.settings
        return VStack(alignment: .leading, spacing: 20) {
            TitledGroup(title: "Accent") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AccentChoice.allCases) { a in
                            Button { s.accent = a } label: {
                                Circle().fill(a.color)
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(Color.white, lineWidth: s.accent == a ? 2.5 : 0).padding(-4))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(a.title)
                            .accessibilityAddTraits(s.accent == a ? .isSelected : [])
                        }
                    }
                    .padding(6)
                }
            }
            TitledGroup(title: "Pokémon Yellow palette") {
                Picker("Palette", selection: $s.retroPalette) {
                    ForEach(RetroPalette.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            TitledGroup(title: "Always On") {
                Picker("Always On", selection: $s.aodAppearance) {
                    ForEach(AODAppearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
    }
}
