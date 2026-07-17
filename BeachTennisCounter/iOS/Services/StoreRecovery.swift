import Foundation
import SwiftData

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

/// A Quarantined Store as the recovery UI sees it: where it is, when it was
/// quarantined, and — if this build can read it — which match ids it holds.
struct QuarantinedStore: Identifiable, Sendable, Equatable {
    enum Contents: Sendable, Equatable {
        /// This build opened a copy of the store and read its match ids.
        case readable(matchIDs: Set<UUID>)
        /// The store exists but this build cannot interpret it (wrong schema
        /// or damaged bytes). Restore is unavailable; Discard still works.
        case unreadable
    }

    let directory: URL
    let quarantinedAt: Date
    let contents: Contents

    var id: URL { directory }
}

/// Moves an unreadable SwiftData store aside so the app can start fresh
/// without destroying the user's data, and gives that store back later:
/// listing, Restore (merge on match id), and Discard.
enum StoreRecovery {
    static let manifestFileName = "manifest.json"

    enum RecoveryError: Error {
        /// The URL is not a quarantine folder under the naming contract —
        /// refuse rather than delete or read something that isn't ours.
        case notAQuarantine
        /// The quarantine has no decodable manifest or no primary store file.
        case unreadableQuarantine
    }

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

    // MARK: - Listing

    /// Every Quarantined Store in `directory`, newest first. Only folders
    /// matching the naming contract with a decodable manifest are recognized;
    /// one that this build cannot open lists as `.unreadable` rather than
    /// failing the whole listing. Never mutates the quarantined files: reads
    /// always go through a scratch copy.
    static func listQuarantinedStores(
        in directory: URL,
        fileManager: FileManager = .default
    ) -> [QuarantinedStore] {
        let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        return names
            .filter { $0.hasPrefix(quarantineDirPrefix) }
            .compactMap { name -> QuarantinedStore? in
                let quarantineDir = directory.appending(path: name)
                guard let manifest = readManifest(in: quarantineDir) else { return nil }
                let contents: QuarantinedStore.Contents
                do {
                    let ids = try withScratchCopy(
                        of: quarantineDir, manifest: manifest, fileManager: fileManager
                    ) { storeURL in
                        try matchIDs(inStoreAt: storeURL)
                    }
                    contents = .readable(matchIDs: ids)
                } catch {
                    contents = .unreadable
                }
                return QuarantinedStore(
                    directory: quarantineDir,
                    quarantinedAt: manifest.quarantinedAt,
                    contents: contents
                )
            }
            .sorted { $0.quarantinedAt > $1.quarantinedAt }
    }

    // MARK: - Restore

    /// Merges the quarantined matches into the live store on match id: a match
    /// whose id is already live is never duplicated and never overwritten.
    /// All-or-nothing — everything missing is inserted in one save, and any
    /// failure leaves the live store untouched. Idempotent by construction, and
    /// never deletes the Quarantined Store.
    /// Returns how many matches were inserted.
    @discardableResult
    static func restore(
        from quarantineDir: URL,
        into liveContainer: ModelContainer,
        fileManager: FileManager = .default
    ) throws -> Int {
        guard quarantineDir.lastPathComponent.hasPrefix(quarantineDirPrefix) else {
            throw RecoveryError.notAQuarantine
        }
        guard let manifest = readManifest(in: quarantineDir) else {
            throw RecoveryError.unreadableQuarantine
        }

        let quarantined = try withScratchCopy(
            of: quarantineDir, manifest: manifest, fileManager: fileManager
        ) { storeURL -> [StoredMatch] in
            let context = ModelContext(try ModelContainer(
                for: StoredMatch.self,
                configurations: ModelConfiguration(url: storeURL)))
            return try context.fetch(FetchDescriptor<StoredMatch>())
        }

        let liveContext = ModelContext(liveContainer)
        let liveIDs = Set(try liveContext.fetch(FetchDescriptor<StoredMatch>()).map(\.id))
        let missing = quarantined.filter { !liveIDs.contains($0.id) }
        guard !missing.isEmpty else { return 0 }

        for match in missing {
            liveContext.insert(StoredMatch(
                id: match.id,
                date: match.date,
                setScoreA: match.setScoreA,
                setScoreB: match.setScoreB,
                setsWonA: match.setsWonA,
                setsWonB: match.setsWonB,
                winner: match.winner,
                duration: match.duration,
                gameHistoryData: match.gameHistoryData,
                setHistoryData: match.setHistoryData,
                matchTypeRaw: match.matchTypeRaw
            ))
        }
        do {
            try liveContext.save()
        } catch {
            liveContext.rollback()
            throw error
        }
        return missing.count
    }

    // MARK: - Discard

    /// Permanently deletes a Quarantined Store — the only user-facing delete
    /// in store recovery. Refuses anything outside the naming contract.
    static func discard(
        _ quarantineDir: URL,
        fileManager: FileManager = .default
    ) throws {
        guard quarantineDir.lastPathComponent.hasPrefix(quarantineDirPrefix) else {
            throw RecoveryError.notAQuarantine
        }
        try fileManager.removeItem(at: quarantineDir)
    }

    // MARK: - Reading a quarantine without touching it

    private static func readManifest(in quarantineDir: URL) -> QuarantineManifest? {
        guard let data = try? Data(
            contentsOf: quarantineDir.appending(path: manifestFileName)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(QuarantineManifest.self, from: data)
    }

    /// Copies the quarantine's store files to a scratch directory and hands
    /// `body` the copied primary store file's URL. The quarantined folder is
    /// never opened as a database, so SQLite housekeeping (WAL checkpoints)
    /// can never mutate the only copy of the player's data.
    private static func withScratchCopy<T>(
        of quarantineDir: URL,
        manifest: QuarantineManifest,
        fileManager: FileManager,
        _ body: (URL) throws -> T
    ) throws -> T {
        // The primary store file is the manifest entry without a sidecar suffix.
        guard let storeFile = manifest.files.first(
            where: { !$0.hasSuffix("-shm") && !$0.hasSuffix("-wal") }) else {
            throw RecoveryError.unreadableQuarantine
        }

        let scratchDir = fileManager.temporaryDirectory
            .appending(path: "restore-scratch-\(UUID().uuidString)")
        try fileManager.createDirectory(at: scratchDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: scratchDir) }

        for file in manifest.files {
            try fileManager.copyItem(
                at: quarantineDir.appending(path: file),
                to: scratchDir.appending(path: file)
            )
        }
        return try body(scratchDir.appending(path: storeFile))
    }

    /// Opening the store doubles as the readability probe: a store this build's
    /// schema cannot interpret throws here and lists as unreadable.
    private static func matchIDs(inStoreAt url: URL) throws -> Set<UUID> {
        let context = ModelContext(try ModelContainer(
            for: StoredMatch.self,
            configurations: ModelConfiguration(url: url)))
        return Set(try context.fetch(FetchDescriptor<StoredMatch>()).map(\.id))
    }
}
