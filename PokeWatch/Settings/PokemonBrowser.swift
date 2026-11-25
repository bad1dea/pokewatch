import SwiftUI

/// Every Pokémon available in the current sprite style, as a grid of sprites.
/// Search by name or number, filter by generation; tap to choose, long-press to
/// add or remove a favourite (favourites are on the Digital Crown wheel).
struct PokemonBrowser: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var generation: Int?

    var body: some View {
        let style = model.settings.spriteStyle
        let all = model.registry.available(in: style)
        let gens = Array(Set(all.map(model.registry.generation(of:)))).sorted()
        let list = all.filter { c in
            (generation == nil || model.registry.generation(of: c) == generation) && matches(c)
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if gens.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            chip("All", selected: generation == nil) { generation = nil }
                            ForEach(gens, id: \.self) { g in
                                chip(Self.roman(g), selected: generation == g) { generation = g }
                            }
                        }
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 60), spacing: 4)], spacing: 4) {
                    ForEach(list) { c in
                        cell(c, style: style)
                    }
                }
                Text("\(list.count) of \(all.count) in \(style.shortTitle) · long-press to favourite")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .searchable(text: $query, prompt: "Name or number")
        .navigationTitle("Pokémon")
    }

    private func matches(_ c: CharacterDefinition) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        if let n = Int(q.trimmingCharacters(in: CharacterSet(charactersIn: "#"))) { return c.dexNumber == n }
        return c.name.localizedCaseInsensitiveContains(q)
    }

    private func cell(_ c: CharacterDefinition, style: SpriteStyle) -> some View {
        let selected = c.id == model.settings.characterID
        let favourite = model.settings.favorites.contains(c.id)
        return Thumbnail(id: c.id, style: style, fallback: c)
            .frame(height: 46)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Palette.faint : Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Palette.electric : .clear, lineWidth: 1.5))
            .overlay(alignment: .topTrailing) {
                if favourite {
                    Circle().fill(Palette.electric).frame(width: 6, height: 6).padding(4)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                model.selectCharacter(c.id)
                dismiss()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                model.settings.toggleFavorite(c.id)
                model.haptic(.click)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(c.name), number \(c.dexNumber)\(favourite ? ", favourite" : "")")
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(selected ? Color.black : Palette.ink)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(selected ? Palette.electric : Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }

    static func roman(_ n: Int) -> String {
        ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"][max(0, min(8, n - 1))]
    }
}

/// First frame of a Pokémon's sprite, from the bundled stills; pixel art when not imported.
private struct Thumbnail: View {
    let id: String
    let style: SpriteStyle
    let fallback: CharacterDefinition

    var body: some View {
        if let image = ThumbnailCache.image(id: id, style: style) {
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .padding(3)
        } else {
            SpriteImage(character: fallback, pixel: 1.5)
        }
    }
}

private enum ThumbnailCache {
    private static let cache = NSCache<NSString, CGImageBox>()

    final class CGImageBox { let image: CGImage; init(_ i: CGImage) { image = i } }

    static func image(id: String, style: SpriteStyle) -> CGImage? {
        let key = "\(style.rawValue)/\(id)" as NSString
        if let hit = cache.object(forKey: key) { return hit.image }
        guard let url = SpriteFiles.stillURL(id: id, style: style, shiny: false),
              let image = SpriteFiles.loadImage(url) else { return nil }
        cache.setObject(CGImageBox(image), forKey: key)
        return image
    }
}
