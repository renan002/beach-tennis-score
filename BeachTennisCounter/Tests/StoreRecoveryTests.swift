import XCTest
@testable import BeachTennisCounter

final class StoreRecoveryTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: tempDir.path)
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func decodeManifest(in quarantineDir: URL) throws -> QuarantineManifest {
        let data = try Data(contentsOf: quarantineDir.appending(path: StoreRecovery.manifestFileName))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(QuarantineManifest.self, from: data)
    }

    func test_movesAllStoreFilesIntoQuarantineDir() throws {
        for suffix in ["", "-shm", "-wal"] {
            try Data("x".utf8).write(to: tempDir.appending(path: "default.store\(suffix)"))
        }

        let quarantine = StoreRecovery.quarantine(in: tempDir, reason: "test")

        let quarantineDir = try XCTUnwrap(quarantine)
        for suffix in ["", "-shm", "-wal"] {
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: tempDir.appending(path: "default.store\(suffix)").path))
            XCTAssertTrue(FileManager.default.fileExists(
                atPath: quarantineDir.appending(path: "default.store\(suffix)").path))
        }
    }

    func test_quarantineDirIsNamedQuarantinedStore() throws {
        try Data("x".utf8).write(to: tempDir.appending(path: "default.store"))

        let quarantineDir = try XCTUnwrap(StoreRecovery.quarantine(in: tempDir, reason: "test"))

        XCTAssertTrue(quarantineDir.lastPathComponent.hasPrefix("quarantined-store-"))
    }

    func test_partialSidecars_movesOnlyExistingFiles() throws {
        try Data("x".utf8).write(to: tempDir.appending(path: "default.store"))

        let quarantine = StoreRecovery.quarantine(in: tempDir, reason: "test")

        let quarantineDir = try XCTUnwrap(quarantine)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: quarantineDir.appending(path: "default.store").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: quarantineDir.appending(path: "default.store-shm").path))
    }

    func test_noStoreFiles_returnsNilAndCreatesNothing() throws {
        XCTAssertNil(StoreRecovery.quarantine(in: tempDir, reason: "test"))
        let contents = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        XCTAssertTrue(contents.isEmpty)
    }

    func test_quarantineDirsFromDifferentTimestampsDoNotCollide() throws {
        try Data("x".utf8).write(to: tempDir.appending(path: "default.store"))
        let first = StoreRecovery.quarantine(
            in: tempDir, reason: "test", now: Date(timeIntervalSince1970: 0))
        try Data("y".utf8).write(to: tempDir.appending(path: "default.store"))
        let second = StoreRecovery.quarantine(
            in: tempDir, reason: "test", now: Date(timeIntervalSince1970: 3600))
        XCTAssertNotEqual(first, second)
    }

    /// Stamps are second-resolution: a same-second retry must still preserve
    /// both stores rather than fall into the delete fallback.
    func test_sameTimestamp_keepsBothStoresInDistinctQuarantineDirs() throws {
        let sameInstant = Date(timeIntervalSince1970: 0)

        try Data("first".utf8).write(to: tempDir.appending(path: "default.store"))
        let first = try XCTUnwrap(StoreRecovery.quarantine(
            in: tempDir, reason: "test", now: sameInstant))
        try Data("second".utf8).write(to: tempDir.appending(path: "default.store"))
        let second = try XCTUnwrap(StoreRecovery.quarantine(
            in: tempDir, reason: "test", now: sameInstant))

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(
            try Data(contentsOf: first.appending(path: "default.store")),
            Data("first".utf8))
        XCTAssertEqual(
            try Data(contentsOf: second.appending(path: "default.store")),
            Data("second".utf8))
    }

    /// If no quarantine directory can be made, the store must be left alone —
    /// the delete fallback must not become the escape hatch.
    func test_unusableQuarantineDir_returnsNilAndLeavesStoreInPlace() throws {
        let store = tempDir.appending(path: "default.store")
        try Data("x".utf8).write(to: store)
        // A read-only parent makes createDirectory fail for real.
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o555], ofItemAtPath: tempDir.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: tempDir.path)
        }

        XCTAssertNil(StoreRecovery.quarantine(in: tempDir, reason: "test"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.path))
    }

    // MARK: - Manifest

    func test_manifest_recordsVersionBuildTimestampReasonAndFiles() throws {
        for suffix in ["", "-shm", "-wal"] {
            try Data("x".utf8).write(to: tempDir.appending(path: "default.store\(suffix)"))
        }
        let instant = Date(timeIntervalSince1970: 1_752_662_400) // whole second: ISO8601 round-trips exactly

        let quarantineDir = try XCTUnwrap(StoreRecovery.quarantine(
            in: tempDir,
            reason: "migration failed: setsWonA has no default",
            now: instant,
            appVersion: "1.2.1",
            build: "5"))

        let manifest = try decodeManifest(in: quarantineDir)
        XCTAssertEqual(manifest.appVersion, "1.2.1")
        XCTAssertEqual(manifest.build, "5")
        XCTAssertEqual(manifest.quarantinedAt, instant)
        XCTAssertEqual(manifest.reason, "migration failed: setsWonA has no default")
        XCTAssertEqual(manifest.files, ["default.store", "default.store-shm", "default.store-wal"])
    }

    func test_manifest_listsOnlyFilesActuallyQuarantined() throws {
        try Data("x".utf8).write(to: tempDir.appending(path: "default.store"))

        let quarantineDir = try XCTUnwrap(StoreRecovery.quarantine(in: tempDir, reason: "test"))

        let manifest = try decodeManifest(in: quarantineDir)
        XCTAssertEqual(manifest.files, ["default.store"])
    }

    func test_manifest_defaultsVersionAndBuildFromBundle() throws {
        try Data("x".utf8).write(to: tempDir.appending(path: "default.store"))

        let quarantineDir = try XCTUnwrap(StoreRecovery.quarantine(in: tempDir, reason: "test"))

        // The test bundle's own values — the point is they are captured, not blank.
        let manifest = try decodeManifest(in: quarantineDir)
        XCTAssertFalse(manifest.appVersion.isEmpty)
        XCTAssertFalse(manifest.build.isEmpty)
    }

    // MARK: - Cap and backup exclusion

    /// Quarantines the store `count` times at one-hour intervals starting from
    /// `start`, re-creating the store between calls (each quarantine moves it
    /// away). Returns the created dirs oldest-first.
    @discardableResult
    private func quarantineRepeatedly(_ count: Int, from start: Date) throws -> [URL] {
        var dirs: [URL] = []
        for i in 0..<count {
            try Data("x".utf8).write(to: tempDir.appending(path: "default.store"))
            let dir = try XCTUnwrap(StoreRecovery.quarantine(
                in: tempDir, reason: "test",
                now: start.addingTimeInterval(Double(i) * 3600)))
            dirs.append(dir)
        }
        return dirs
    }

    private func quarantineDirs() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix(StoreRecovery.quarantineDirPrefix) }
    }

    /// Plants a pre-existing quarantine folder with a chosen name and manifest
    /// timestamp — letting a test set folder-name order and manifest-recency
    /// order independently.
    private func plantQuarantine(named name: String, quarantinedAt: Date) throws {
        let dir = tempDir.appending(path: name)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let manifest = QuarantineManifest(
            appVersion: "1.0", build: "1", quarantinedAt: quarantinedAt,
            reason: "planted", files: ["default.store"])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(
            to: dir.appending(path: StoreRecovery.manifestFileName))
    }

    func test_capsQuarantinesAtNewestThree() throws {
        try quarantineRepeatedly(4, from: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(try quarantineDirs().count, StoreRecovery.maxQuarantineCount)
    }

    func test_underCap_keepsAllQuarantines() throws {
        try quarantineRepeatedly(3, from: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(try quarantineDirs().count, 3)
    }

    /// The pruned folder is the oldest by manifest recency, and the newest three
    /// survive — established through their manifest timestamps, not folder names.
    func test_prunesOldestByRecency_keepingNewest() throws {
        let start = Date(timeIntervalSince1970: 0)
        try quarantineRepeatedly(4, from: start)

        let survivingDates = try quarantineDirs().map { dir -> Date in
            let data = try Data(contentsOf: dir.appending(path: StoreRecovery.manifestFileName))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(QuarantineManifest.self, from: data).quarantinedAt
        }.sorted()

        XCTAssertEqual(survivingDates, [
            start.addingTimeInterval(3600),
            start.addingTimeInterval(7200),
            start.addingTimeInterval(10800),
        ])
    }

    /// The AC that matters most: pruning follows manifest recency, not folder
    /// name. Here the two orders are deliberately reversed — the lexically
    /// *smallest* name holds the *newest* manifest — so a name-sort would prune
    /// the wrong folder and this test would fail.
    func test_prunesByManifestRecency_notByFolderName() throws {
        // name order ascending: 2000 < 2001 < 2002 ; manifest recency reversed.
        try plantQuarantine(named: "quarantined-store-2000-01-01T00-00-00Z",
                            quarantinedAt: Date(timeIntervalSince1970: 4000)) // newest manifest, oldest name
        try plantQuarantine(named: "quarantined-store-2001-01-01T00-00-00Z",
                            quarantinedAt: Date(timeIntervalSince1970: 3000))
        try plantQuarantine(named: "quarantined-store-2002-01-01T00-00-00Z",
                            quarantinedAt: Date(timeIntervalSince1970: 2000)) // oldest manifest

        // A fourth quarantine trips the cap and prunes exactly one folder.
        try Data("x".utf8).write(to: tempDir.appending(path: "default.store"))
        _ = try XCTUnwrap(StoreRecovery.quarantine(
            in: tempDir, reason: "test", now: Date(timeIntervalSince1970: 2500)))

        let names = Set(try quarantineDirs().map(\.lastPathComponent))
        // Kept despite its oldest name — newest by manifest.
        XCTAssertTrue(names.contains("quarantined-store-2000-01-01T00-00-00Z"))
        // Pruned despite not being the oldest name — oldest by manifest.
        XCTAssertFalse(names.contains("quarantined-store-2002-01-01T00-00-00Z"))
    }

    func test_quarantineDir_isExcludedFromBackup() throws {
        try Data("x".utf8).write(to: tempDir.appending(path: "default.store"))

        let quarantineDir = try XCTUnwrap(StoreRecovery.quarantine(in: tempDir, reason: "test"))

        let values = try quarantineDir.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }
}
