import SwiftUI

/// Home: the watch face as it looks right now, and the controls that matter most.
/// Side by side when the screen is wider than tall, stacked otherwise.
struct CompanionScreen: View {
    @Environment(PhoneModel.self) private var model

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height * 1.05 && geo.size.width > 520
            ScrollView {
                if wide {
                    HStack(alignment: .top, spacing: 28) {
                        preview(width: min(geo.size.height * 0.62, geo.size.width * 0.38))
                        controls.frame(maxWidth: 520)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 20) {
                        preview(width: min(geo.size.width * 0.56, 240))
                        controls
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Color.black)
        .navigationTitle("PokéWatch")
        .toolbarTitleDisplayMode(.inline)
    }

    private func preview(width: CGFloat) -> some View {
        VStack(spacing: 10) {
            WatchFacePreview(face: model.settings.faceStyle, width: width)
            Text("\(model.settings.faceStyle.number) · \(model.settings.faceStyle.title)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.dim)
        }
    }

    private var controls: some View {
        let c = model.character
        let entry = model.registry.entry(c.id)
        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(c.dexLabel)
                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                    .foregroundStyle(Palette.dim)
                HStack(alignment: .firstTextBaseline) {
                    Text(c.name)
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    FavouriteButton(id: c.id)
                }
                Text([c.category.isEmpty ? nil : "\(c.category) Pokémon", entry.map { "Gen \(PokemonGrid.roman($0.generation))" }]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Palette.dim)
                TypeChips(types: entry?.types ?? [c.type.lowercased()])
            }

            TitledGroup(title: "Sprites") {
                StyleChips()
                Toggle(isOn: Binding(get: { model.settings.shiny }, set: { model.settings.shiny = $0 })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shiny")
                        if !model.sync.watchPacks.contains(.shiny) {
                            Text("Shows on the watch once the Shiny pack is sent (Watch tab).")
                                .font(.caption)
                                .foregroundStyle(Palette.dim)
                        }
                    }
                }
            }

            TitledGroup(title: "Favourites on the Crown") {
                FavouritesStrip()
            }

            TitledGroup(title: "Routine") {
                Picker("Animation", selection: Binding(get: { model.settings.variant },
                                                       set: { model.settings.variant = $0 })) {
                    ForEach(AnimationVariant.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

/// Titled group used across the phone screens.
struct TitledGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(Palette.dim)
            content
        }
    }
}

struct FavouriteButton: View {
    @Environment(PhoneModel.self) private var model
    let id: String

    var body: some View {
        let on = model.isFavourite(id)
        Button {
            model.settings.toggleFavorite(id)
        } label: {
            Label(on ? "Favourite" : "Add to favourites", systemImage: on ? "star.fill" : "star")
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(on ? Palette.electric : Palette.dim)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(on ? "Remove from favourites" : "Add to favourites")
    }
}

struct TypeChips: View {
    let types: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(types, id: \.self) { t in
                Text(t.capitalized)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(TypeColor.of(t))
                    .overlay(Capsule().stroke(TypeColor.of(t).opacity(0.6), lineWidth: 1))
            }
        }
    }
}

enum TypeColor {
    static func of(_ t: String) -> Color {
        switch t {
        case "electric": Color(hex: "#FFE100")
        case "fire": Color(hex: "#FF8A3D")
        case "water": Color(hex: "#5CC8F0")
        case "grass": Color(hex: "#7CD67A")
        case "ice": Color(hex: "#9FE6F2")
        case "fighting": Color(hex: "#E8774A")
        case "poison": Color(hex: "#B97FD9")
        case "ground": Color(hex: "#D8B46A")
        case "flying": Color(hex: "#A9C4F5")
        case "psychic": Color(hex: "#FF9ACB")
        case "bug": Color(hex: "#B5D44A")
        case "rock": Color(hex: "#C9B074")
        case "ghost": Color(hex: "#A77BE8")
        case "dragon": Color(hex: "#8C7CF0")
        case "dark": Color(hex: "#B0A090")
        case "steel": Color(hex: "#B8C4D0")
        case "fairy": Color(hex: "#FFB4D6")
        default: Color(hex: "#E8E2D0")
        }
    }
}

/// The six sprite styles; ones the current Pokémon wasn't in are marked.
struct StyleChips: View {
    @Environment(PhoneModel.self) private var model

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SpriteStyle.allCases) { style in
                    let selected = model.settings.spriteStyle == style
                    let has = model.registry.isAvailable(model.settings.characterID, in: style)
                    Button { model.setStyle(style) } label: {
                        VStack(spacing: 4) {
                            StillImage(id: has ? model.settings.characterID : "pikachu", style: style, shiny: model.settings.shiny)
                                .frame(width: 48, height: 48)
                                .opacity(has ? 1 : 0.35)
                            Text(style.shortTitle)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(selected ? Palette.electric : Palette.ink)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(selected ? 0.12 : 0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Palette.electric : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(style.title)\(has ? "" : ", not in this generation")")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        Text(model.registry.isAvailable(model.settings.characterID, in: model.settings.spriteStyle)
             ? model.settings.spriteStyle.title
             : "\(model.character.name) isn't in \(model.settings.spriteStyle.shortTitle).")
            .font(.caption)
            .foregroundStyle(Palette.dim)
    }
}

struct FavouritesStrip: View {
    @Environment(PhoneModel.self) private var model

    var body: some View {
        let favs = model.favourites(in: model.settings.spriteStyle)
        if favs.isEmpty {
            Text("Star a Pokémon to put it on the watch's Crown wheel.")
                .font(.footnote)
                .foregroundStyle(Palette.dim)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(favs) { c in
                        PokemonTile(character: c, compact: true)
                            .frame(width: 64)
                    }
                }
            }
        }
    }
}

/// First frame of a sprite, crisp at any size.
struct StillImage: View {
    let id: String
    let style: SpriteStyle
    var shiny = false

    var body: some View {
        if let cg = StillCache.image(id: id, style: style, shiny: shiny) {
            Image(decorative: cg, scale: 1)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
        } else if let c = Optional(CharacterRegistry.shared.character(id)), c.hasPixelArt {
            SpriteImage(character: c, pixel: 2).scaledToFit()
        } else {
            Color.clear
        }
    }
}
