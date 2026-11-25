import Foundation

/// Extra sprite sets the iPhone app can send to the watch. They don't fit in the watch app
/// (Apple caps it at 75 MB), so the watch stores them in Application Support after install.
enum SpritePackKind: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Shiny colours for every style.
    case shiny
    /// The Modern style at its full frame rate (the watch app ships it at half rate).
    case fullModern

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shiny: "Shiny colours"
        case .fullModern: "Full-motion Modern"
        }
    }

    var detail: String {
        switch self {
        case .shiny: "Shiny sprites for every generation."
        case .fullModern: "Every frame of the Modern style's animations, twice as smooth."
        }
    }

    /// Relative sprite folders (`<style>/<id>/<variant>`) the pack contains.
    func includes(style: String, variant: String) -> Bool {
        switch self {
        case .shiny: variant == "shiny"
        case .fullModern: style == SpriteStyle.modern.rawValue && variant == "normal"
        }
    }

    /// Bump when a pack's content changes so the watch knows to replace it.
    static let formatVersion = 1
}

/// A single-file archive of many small files, so one `WCSession.transferFile` moves a whole pack.
///
/// Layout: `PWPK` magic, UInt32 version, UInt64 index length, JSON index `[{path, offset, length}]`,
/// then the file bytes back to back. Offsets are relative to the start of the data section.
enum SpritePackArchive {
    struct Entry: Codable, Equatable {
        let path: String
        let offset: UInt64
        let length: UInt64
    }

    enum ArchiveError: Error { case badMagic, badIndex, unsafePath(String), truncated }

    static let magic = Data("PWPK".utf8)

    /// Writes `files` (archive path → source file) to `destination`.
    static func write(_ files: [(path: String, source: URL)], to destination: URL) throws {
        var index: [Entry] = []
        var offset: UInt64 = 0
        var sizes: [UInt64] = []
        for f in files {
            let size = (try FileManager.default.attributesOfItem(atPath: f.source.path)[.size] as? NSNumber)?.uint64Value ?? 0
            index.append(Entry(path: f.path, offset: offset, length: size))
            sizes.append(size)
            offset += size
        }
        let indexData = try JSONEncoder().encode(index)
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let out = try FileHandle(forWritingTo: destination)
        defer { try? out.close() }
        var header = magic
        header.append(contentsOf: withUnsafeBytes(of: UInt32(1).littleEndian, Array.init))
        header.append(contentsOf: withUnsafeBytes(of: UInt64(indexData.count).littleEndian, Array.init))
        try out.write(contentsOf: header)
        try out.write(contentsOf: indexData)
        for f in files { try out.write(contentsOf: try Data(contentsOf: f.source)) }
    }

    /// Unpacks `archive` into `directory`, refusing paths that would escape it.
    @discardableResult
    static func unpack(_ archive: URL, into directory: URL) throws -> Int {
        let data = try Data(contentsOf: archive, options: .mappedIfSafe)
        guard data.count >= 16, data.prefix(4) == magic else { throw ArchiveError.badMagic }
        let indexLength = data.subdata(in: 8..<16).withUnsafeBytes { $0.loadUnaligned(as: UInt64.self).littleEndian }
        let indexStart = 16, dataStart = 16 + Int(indexLength)
        guard dataStart <= data.count else { throw ArchiveError.truncated }
        guard let index = try? JSONDecoder().decode([Entry].self, from: data.subdata(in: indexStart..<dataStart)) else {
            throw ArchiveError.badIndex
        }
        let fm = FileManager.default
        let base = directory.standardizedFileURL.path
        for e in index {
            guard !e.path.hasPrefix("/"), !e.path.split(separator: "/").contains("..") else { throw ArchiveError.unsafePath(e.path) }
            let start = dataStart + Int(e.offset), end = start + Int(e.length)
            guard end <= data.count else { throw ArchiveError.truncated }
            let target = directory.appendingPathComponent(e.path).standardizedFileURL
            guard target.path.hasPrefix(base) else { throw ArchiveError.unsafePath(e.path) }
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.subdata(in: start..<end).write(to: target)
        }
        return index.count
    }
}

/// Where the watch keeps installed packs: `Application Support/SpritePacks/<kind>/`.
enum SpritePackStore {
    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("SpritePacks", isDirectory: true)
    }

    static func directory(_ kind: SpritePackKind) -> URL { root.appendingPathComponent(kind.rawValue, isDirectory: true) }

    static var installed: [SpritePackKind] {
        SpritePackKind.allCases.filter {
            FileManager.default.fileExists(atPath: directory($0).appendingPathComponent(".complete").path)
        }
    }

    /// Full-rate Modern first, so it replaces the bundled half-rate frames.
    static var spriteRoots: [URL] {
        [SpritePackKind.fullModern, .shiny].filter(installed.contains).map(directory)
    }

    static func install(archive: URL, kind: SpritePackKind) throws {
        let fm = FileManager.default
        let dir = directory(kind)
        let staging = root.appendingPathComponent(".\(kind.rawValue)-incoming", isDirectory: true)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        try SpritePackArchive.unpack(archive, into: staging)
        fm.createFile(atPath: staging.appendingPathComponent(".complete").path, contents: Data("\(SpritePackKind.formatVersion)".utf8))
        try? fm.removeItem(at: dir)
        try fm.moveItem(at: staging, to: dir)
    }

    static func remove(_ kind: SpritePackKind) {
        try? FileManager.default.removeItem(at: directory(kind))
    }
}
