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

    static let quarantineDirPrefix = "quarantined-store-"

    /// Quarantined stores kept on disk; older ones are pruned. Bounds both disk
    /// use and the device's iCloud backup: a schema-invalid store crash-loops,
    /// writing a partial store — and so one quarantine folder — on every launch,
    /// which would otherwise accumulate without limit. The newest is the one a
    /// restore would target, so recency is what the cap keeps.
    static let maxQuarantineCount = 3

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
        var quarantineDir = directory.appending(path: "\(quarantineDirPrefix)\(stamp)")
        var attempt = 2
        while fileManager.fileExists(atPath: quarantineDir.path) {
            quarantineDir = directory.appending(path: "\(quarantineDirPrefix)\(stamp)-\(attempt)")
            attempt += 1
        }

        do {
            try fileManager.createDirectory(at: quarantineDir, withIntermediateDirectories: true)
        } catch {
            // Without a quarantine directory the moves below would each fail
            // into the delete fallback, destroying the data we came to save.
            return nil
        }

        // Keep the quarantined store out of the device's iCloud backup;
        // Application Support rides along in it by default.
        var excludeFromBackup = URLResourceValues()
        excludeFromBackup.isExcludedFromBackup = true
        try? quarantineDir.setResourceValues(excludeFromBackup)

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

        pruneOldQuarantines(in: directory, fileManager: fileManager)

        return quarantineDir
    }

    /// Deletes quarantined stores beyond the newest `maxQuarantineCount`,
    /// ordering by quarantine recency rather than folder name — the name is not
    /// sortable, since a same-second retry appends `-2`/`-3` and the prefix was
    /// renamed (#40). The manifest's `quarantinedAt` is authoritative; a folder
    /// missing or with an unreadable manifest falls back to its creation date.
    private static func pruneOldQuarantines(in directory: URL, fileManager: FileManager) {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: []
        ) else { return }

        let quarantines = entries.filter { $0.lastPathComponent.hasPrefix(quarantineDirPrefix) }
        guard quarantines.count > maxQuarantineCount else { return }

        let byRecency = quarantines
            .map { (url: $0, date: quarantineDate(of: $0, fileManager: fileManager)) }
            .sorted { $0.date > $1.date }
        for stale in byRecency.dropFirst(maxQuarantineCount) {
            try? fileManager.removeItem(at: stale.url)
        }
    }

    /// When a store was quarantined, read from its manifest. A manifest-less
    /// folder (a crash before the write) falls back to its creation date — still
    /// a fair recency proxy — and only a folder with neither sorts `.distantPast`
    /// and is pruned first.
    private static func quarantineDate(of dir: URL, fileManager: FileManager) -> Date {
        if let data = try? Data(contentsOf: dir.appending(path: manifestFileName)) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let manifest = try? decoder.decode(QuarantineManifest.self, from: data) {
                return manifest.quarantinedAt
            }
        }
        if let created = (try? fileManager.attributesOfItem(atPath: dir.path))?[.creationDate] as? Date {
            return created
        }
        return .distantPast
    }
}
