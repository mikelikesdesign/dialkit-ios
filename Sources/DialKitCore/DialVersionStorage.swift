import CryptoKit
import Foundation

/// Keep the small model archive in preferences and image bytes in Application Support.
struct DialVersionStorage<Model: Codable & Equatable> {
    struct Archive: Codable {
        let base: Model
        let baseName: String
        let presets: [DialPreset<Model>]
        let activeID: UUID?
    }

    static var thumbnailLimit: Int { 256 * 1024 }

    private let defaults: UserDefaults
    private let key: String
    private let directory: URL?

    init(_ persistKey: String, defaults: UserDefaults = .standard,
         supportDirectory: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first) {
        self.defaults = defaults
        key = "DialKit.versions." + persistKey
        let folder = SHA256.hash(data: Data(persistKey.utf8)).map { String(format: "%02x", $0) }.joined()
        directory = supportDirectory?
            .appendingPathComponent("DialKit/VersionPreviews/" + folder, isDirectory: true)
    }

    func read() -> Archive? {
        guard let data = defaults.data(forKey: key),
              let archive = try? JSONDecoder().decode(Archive.self, from: data),
              Set(archive.presets.map(\.id)).count == archive.presets.count else { return nil }
        return archive
    }

    func write(_ archive: Archive) {
        guard let data = try? JSONEncoder().encode(archive) else { return }
        defaults.set(data, forKey: key)
    }

    func resetThumbnails() {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    private func url(for id: UUID?) -> URL? {
        directory?.appendingPathComponent((id?.uuidString ?? "base") + ".jpg")
    }

    func thumbnail(for id: UUID?) -> Data? {
        guard let url = url(for: id),
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= Self.thumbnailLimit else { return nil }
        return try? Data(contentsOf: url)
    }

    func setThumbnail(_ data: Data?, for id: UUID?) {
        guard let directory, let url = url(for: id) else { return }
        if let data {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
