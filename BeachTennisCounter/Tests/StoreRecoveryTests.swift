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

    func test_movesAllStoreFilesIntoBackupDir() throws {
        for suffix in ["", "-shm", "-wal"] {
            try Data("x".utf8).write(to: tempDir.appending(path: "default.store\(suffix)"))
        }

        let backup = StoreRecovery.moveStoreAside(in: tempDir)

        let backupDir = try XCTUnwrap(backup)
        for suffix in ["", "-shm", "-wal"] {
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: tempDir.appending(path: "default.store\(suffix)").path))
            XCTAssertTrue(FileManager.default.fileExists(
                atPath: backupDir.appending(path: "default.store\(suffix)").path))
        }
    }

    func test_partialSidecars_movesOnlyExistingFiles() throws {
        try Data("x".utf8).write(to: tempDir.appending(path: "default.store"))

        let backup = StoreRecovery.moveStoreAside(in: tempDir)

        let backupDir = try XCTUnwrap(backup)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: backupDir.appending(path: "default.store").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: backupDir.appending(path: "default.store-shm").path))
    }

    func test_noStoreFiles_returnsNilAndCreatesNothing() throws {
        XCTAssertNil(StoreRecovery.moveStoreAside(in: tempDir))
        let contents = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        XCTAssertTrue(contents.isEmpty)
    }

    func test_backupDirsFromDifferentTimestampsDoNotCollide() throws {
        try Data("x".utf8).write(to: tempDir.appending(path: "default.store"))
        let first = StoreRecovery.moveStoreAside(in: tempDir, now: Date(timeIntervalSince1970: 0))
        try Data("y".utf8).write(to: tempDir.appending(path: "default.store"))
        let second = StoreRecovery.moveStoreAside(in: tempDir, now: Date(timeIntervalSince1970: 3600))
        XCTAssertNotEqual(first, second)
    }

    /// Stamps are second-resolution: a same-second retry must still preserve
    /// both stores rather than fall into the delete fallback.
    func test_sameTimestamp_keepsBothStoresInDistinctBackupDirs() throws {
        let sameInstant = Date(timeIntervalSince1970: 0)

        try Data("first".utf8).write(to: tempDir.appending(path: "default.store"))
        let first = try XCTUnwrap(StoreRecovery.moveStoreAside(in: tempDir, now: sameInstant))
        try Data("second".utf8).write(to: tempDir.appending(path: "default.store"))
        let second = try XCTUnwrap(StoreRecovery.moveStoreAside(in: tempDir, now: sameInstant))

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(
            try Data(contentsOf: first.appending(path: "default.store")),
            Data("first".utf8))
        XCTAssertEqual(
            try Data(contentsOf: second.appending(path: "default.store")),
            Data("second".utf8))
    }

    /// If no backup directory can be made, the store must be left alone — the
    /// delete fallback must not become the escape hatch.
    func test_unusableBackupDir_returnsNilAndLeavesStoreInPlace() throws {
        let store = tempDir.appending(path: "default.store")
        try Data("x".utf8).write(to: store)
        // A read-only parent makes createDirectory fail for real.
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o555], ofItemAtPath: tempDir.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: tempDir.path)
        }

        XCTAssertNil(StoreRecovery.moveStoreAside(in: tempDir))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.path))
    }
}
