import Foundation

/// What a later build needs to know to read a Quarantined Store back: there
/// are no VersionedSchema types in the project, so the app version that wrote
/// the store is the only proxy for its schema, and it is only knowable at
/// quarantine time.
struct QuarantineManifest: Codable, Equatable {
    let appVersion: String
    let build: String
    let quarantinedAt: Date
    let reason: String
    let files: [String]
}

/// Moves an unreadable SwiftData store aside so the app can start fresh
/// without destroying the user's data.
enum StoreRecovery {
    static let manifestFileName = "manifest.json"

    /// Quarantines `<storeName>` (+ `-shm`/`-wal` sidecars) from `directory`
    /// into a timestamped `quarantined-store-<date>` folder next to them,
    /// recording a manifest alongside the files.
    /// Returns the quarantine directory, or nil if no store files existed or
    /// no usable quarantine directory could be created.
    @discardableResult
    static func quarantine(
        in directory: URL,
        reason: String,
        storeName: String = "default.store",
        fileManager: FileManager = .default,
        now: Date = Date(),
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
        build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    ) -> URL? {
        let suffixes = ["", "-shm", "-wal"]
        let sources = suffixes.map { directory.appending(path: "\(storeName)\($0)") }
        guard sources.contains(where: { fileManager.fileExists(atPath: $0.path) }) else {
            return nil
        }

        // Stamps are second-resolution, so two quarantines within the same
        // second would otherwise reuse one directory and collide on move.
        let stamp = ISO8601DateFormatter().string(from: now)
            .replacingOccurrences(of: ":", with: "-")
        var quarantineDir = directory.appending(path: "quarantined-store-\(stamp)")
        var attempt = 2
        while fileManager.fileExists(atPath: quarantineDir.path) {
            quarantineDir = directory.appending(path: "quarantined-store-\(stamp)-\(attempt)")
            attempt += 1
        }

        do {
            try fileManager.createDirectory(at: quarantineDir, withIntermediateDirectories: true)
        } catch {
            // Without a quarantine directory the moves below would each fail
            // into the delete fallback, destroying the data we came to save.
            return nil
        }

        var quarantinedFiles: [String] = []
        for source in sources where fileManager.fileExists(atPath: source.path) {
            do {
                try fileManager.moveItem(
                    at: source,
                    to: quarantineDir.appending(path: source.lastPathComponent)
                )
                quarantinedFiles.append(source.lastPathComponent)
            } catch {
                // Last resort: the fresh store cannot be created while this
                // file is in place, so fall back to removing it.
                try? fileManager.removeItem(at: source)
            }
        }

        // A failed manifest write must never delete anything: the files are
        // already safely moved, and a manifest-less quarantine still beats a
        // destroyed store.
        let manifest = QuarantineManifest(
            appVersion: appVersion,
            build: build,
            quarantinedAt: now,
            reason: reason,
            files: quarantinedFiles
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(manifest) {
            try? data.write(to: quarantineDir.appending(path: manifestFileName))
        }

        return quarantineDir
    }
}
