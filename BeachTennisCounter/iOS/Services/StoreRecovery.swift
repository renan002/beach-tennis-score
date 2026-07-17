import Foundation

/// Moves an unreadable SwiftData store aside so the app can start fresh
/// without destroying the user's data.
enum StoreRecovery {
    /// Moves `<storeName>` (+ `-shm`/`-wal` sidecars) from `directory` into a
    /// timestamped `corrupt-store-<date>` folder next to them.
    /// Returns the backup directory, or nil if no store files existed or no
    /// usable backup directory could be created.
    @discardableResult
    static func moveStoreAside(
        in directory: URL,
        storeName: String = "default.store",
        fileManager: FileManager = .default,
        now: Date = Date()
    ) -> URL? {
        let suffixes = ["", "-shm", "-wal"]
        let sources = suffixes.map { directory.appending(path: "\(storeName)\($0)") }
        guard sources.contains(where: { fileManager.fileExists(atPath: $0.path) }) else {
            return nil
        }

        // Stamps are second-resolution, so two recoveries within the same
        // second would otherwise reuse one directory and collide on move.
        let stamp = ISO8601DateFormatter().string(from: now)
            .replacingOccurrences(of: ":", with: "-")
        var backupDir = directory.appending(path: "corrupt-store-\(stamp)")
        var attempt = 2
        while fileManager.fileExists(atPath: backupDir.path) {
            backupDir = directory.appending(path: "corrupt-store-\(stamp)-\(attempt)")
            attempt += 1
        }

        do {
            try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        } catch {
            // Without a backup directory the moves below would each fail into
            // the delete fallback, destroying the data we came here to save.
            return nil
        }

        for source in sources where fileManager.fileExists(atPath: source.path) {
            do {
                try fileManager.moveItem(
                    at: source,
                    to: backupDir.appending(path: source.lastPathComponent)
                )
            } catch {
                // Last resort: the fresh store cannot be created while this
                // file is in place, so fall back to removing it.
                try? fileManager.removeItem(at: source)
            }
        }
        return backupDir
    }
}
