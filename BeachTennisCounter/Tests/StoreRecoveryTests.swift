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
}
