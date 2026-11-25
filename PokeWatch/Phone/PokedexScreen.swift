import SwiftUI

/// Every Pokémon in the current sprite style, searchable, filterable by generation.
struct PokedexScreen: View {
    @Environment(PhoneModel.self) private var model
    @State private var query = ""
    @State private var generation: Int?
    @State private var favouritesOnly = false

    var body: some View {
        let style = model.settings.spriteStyle
        let all = model.registry.available(in: style)
        let list = all.filter { c in
            (generation == nil || model.registry.generation(of: c) == generation)
                && (!favouritesOnly || model.isFavourite(c.id))
                && matches(c)
        }
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    GenerationBar(style: style, selection: $generation)
                    PokemonGrid(characters: list, width: geo.size.width)
                    Text("\(list.count) of \(all.count) in \(style.title). Long-press for favourites.")
                        .font(.footnote)
                        .foregroundStyle(Palette.dim)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.black)
        .navigationTitle("Pokédex")
        .searchable(text: $query, prompt: "Name or number")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Sprites", selection: Binding(get: { model.settings.spriteStyle }, set: model.setStyle)) {
                        ForEach(SpriteStyle.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Favourites only", isOn: $favouritesOnly)
                } label: {
                    Label("Options", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    private func matches(_ c: CharacterDefinition) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        if let n = Int(q.trimmingCharacters(in: CharacterSet(charactersIn: "#"))) { return c.dexNumber == n }
        return c.name.localizedCaseInsensitiveContains(q)
    }
}

struct GenerationBar: View {
    @Environment(PhoneModel.self) private var model
    let style: SpriteStyle
    @Binding var selection: Int?

    var body: some View {
        let gens = Array(Set(model.registry.available(in: style).map(model.registry.generation(of:)))).sorted()
        if gens.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip("All", selection == nil) { selection = nil }
                    ForEach(gens, id: \.self) { g in chip("Gen \(PokemonGrid.roman(g))", selection == g) { selection = g } }
                }
            }
        }
    }

    private func chip(_ title: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(on ? Color.black : Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(on ? Palette.electric : Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

struct PokemonGrid: View {
    let characters: [CharacterDefinition]
    let width: CGFloat

    var body: some View {
        // ~4 columns on a narrow phone, more as the screen widens.
        let minimum: CGFloat = width < 420 ? 72 : (width < 700 ? 84 : 96)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum), spacing: 8)], spacing: 8) {
            ForEach(characters) { PokemonTile(character: $0) }
        }
    }

    static func roman(_ n: Int) -> String {
        ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"][max(0, min(8, n - 1))]
    }
}

/// A Pokémon in a grid: sprite, number and name. Tap to choose, long-press for favourites.
struct PokemonTile: View {
    @Environment(PhoneModel.self) private var model
    let character: CharacterDefinition
    var compact = false

    var body: some View {
        let c = character
        let selected = c.id == model.settings.characterID
        let fav = model.isFavourite(c.id)
        Button { model.select(c.id) } label: {
            VStack(spacing: 2) {
                StillImage(id: c.id, style: model.settings.spriteStyle, shiny: model.settings.shiny)
                    .frame(height: compact ? 44 : 56)
                if !compact {
                    Text(String(format: "%03d", c.dexNumber))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    Text(c.name)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(selected ? 0.14 : 0.05)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Palette.electric : .clear, lineWidth: 1.5))
            .overlay(alignment: .topTrailing) {
                if fav {
                    Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(Palette.electric).padding(5)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(fav ? "Remove from favourites" : "Add to favourites", systemImage: fav ? "star.slash" : "star") {
                model.settings.toggleFavorite(c.id)
            }
        }
        .accessibilityLabel("\(c.name), number \(c.dexNumber)\(fav ? ", favourite" : "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
