import Foundation
import Observation
import SwiftUI

/// State of the iPhone app: the same settings the watch uses, kept in sync over
/// WatchConnectivity, plus sprite packs to send to the watch.
@MainActor @Observable
final class PhoneModel {
    let settings: SettingsStore
    let registry = CharacterRegistry.shared
    let sync = SyncService()
    let packs = PackBuilder()
    let launch = LaunchOptions.current

    init(defaults: UserDefaults = .standard) {
        settings = SettingsStore(defaults: defaults)
        settings.applyLaunchOverrides(launch)
        settings.onLocalChange = { [weak self] in self?.publish() }
        sync.onSettings = { [weak self] payload in self?.settings.apply(syncPayload: payload) }
        sync.activate()
        publish()
    }

    var character: CharacterDefinition { registry.character(settings.characterID) }
    var art: ArtChoice { ArtChoice(style: settings.spriteStyle, shiny: settings.shiny) }

    func publish() { sync.publish(settings: settings.syncPayload) }

    func select(_ id: String) {
        guard id != settings.characterID else { return }
        settings.characterID = id
    }

    func isFavourite(_ id: String) -> Bool { settings.favorites.contains(id) }

    /// Era-accurate styles: switching to a generation the current Pokémon wasn't in picks the
    /// first favourite that existed then (same rule as the watch).
    func setStyle(_ style: SpriteStyle) {
        settings.spriteStyle = style
        guard !registry.isAvailable(settings.characterID, in: style) else { return }
        let next = settings.favorites.first { registry.isAvailable($0, in: style) }
            ?? registry.available(in: style).first?.id ?? "pikachu"
        settings.characterID = next
    }

    func favourites(in style: SpriteStyle) -> [CharacterDefinition] {
        settings.favorites.filter { registry.isAvailable($0, in: style) }.map(registry.character)
    }

    func send(_ pack: SpritePackKind) {
        Task {
            guard let file = await packs.archive(pack) else { return }
            sync.send(pack: pack, file: file)
        }
    }

    enum PackState: Equatable { case unavailable, ready, building, sending(Double), installed }

    func state(of pack: SpritePackKind) -> PackState {
        if sync.watchPacks.contains(pack) { return .installed }
        if let p = sync.transfers[pack] { return .sending(p) }
        if packs.building.contains(pack) { return .building }
        return sync.paired && sync.watchAppInstalled ? .ready : .unavailable
    }
}

/// Builds sprite-pack archives from the sprites bundled in the iPhone app, once per version,
/// in the background. They are cached in Caches and rebuilt if missing.
@MainActor @Observable
final class PackBuilder {
    private(set) var building: Set<SpritePackKind> = []
    private(set) var sizes: [SpritePackKind: Int64] = [:]

    private nonisolated static var spritesRoot: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("ImportedSprites", isDirectory: true)
    }

    private nonisolated static func cacheURL(_ kind: SpritePackKind) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("\(kind.rawValue)-v\(SpritePackKind.formatVersion).pwpk")
    }

    /// The files in a pack: (archive path, source URL).
    nonisolated static func files(for kind: SpritePackKind) -> [(path: String, source: URL)] {
        guard let root = spritesRoot else { return [] }
        let fm = FileManager.default
        var out: [(String, URL)] = []
        for style in (try? fm.contentsOfDirectory(atPath: root.path)) ?? [] {
            let styleDir = root.appendingPathComponent(style)
            for id in (try? fm.contentsOfDirectory(atPath: styleDir.path)) ?? [] {
                for variant in ["normal", "shiny"] where kind.includes(style: style, variant: variant) {
                    let dir = styleDir.appendingPathComponent("\(id)/\(variant)")
                    for name in ["manifest.json", "sheet.png"] {
                        let f = dir.appendingPathComponent(name)
                        if fm.fileExists(atPath: f.path) { out.append(("\(style)/\(id)/\(variant)/\(name)", f)) }
                    }
                }
            }
        }
        return out
    }

    func measure() {
        guard sizes.isEmpty else { return }
        Task.detached(priority: .utility) {
            var result: [SpritePackKind: Int64] = [:]
            for kind in SpritePackKind.allCases {
                result[kind] = Self.files(for: kind).reduce(0) { sum, f in
                    sum + ((try? FileManager.default.attributesOfItem(atPath: f.source.path)[.size] as? NSNumber)?.int64Value ?? 0)
                }
            }
            let measured = result
            await MainActor.run { self.sizes = measured }
        }
    }

    func archive(_ kind: SpritePackKind) async -> URL? {
        let url = Self.cacheURL(kind)
        if FileManager.default.fileExists(atPath: url.path) { return url }
        building.insert(kind)
        defer { building.remove(kind) }
        return await Task.detached(priority: .userInitiated) { () -> URL? in
            let files = Self.files(for: kind)
            guard !files.isEmpty else { return nil }
            let temp = url.appendingPathExtension("partial")
            do {
                try SpritePackArchive.write(files, to: temp)
                try? FileManager.default.removeItem(at: url)
                try FileManager.default.moveItem(at: temp, to: url)
                return url
            } catch {
                return nil
            }
        }.value
    }
}
