import XCTest
import SwiftData
@testable import BeachTennisCounter

/// Listing, restoring, and discarding Quarantined Stores — exercised through
/// real SwiftData stores in a temp directory, quarantined with the real
/// quarantine function, per the spec's testing seam.
final class StoreRecoveryRestoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Fixtures

    private func makeMatch(
        id: UUID = UUID(),
        duration: TimeInterval = 60,
        gameHistoryData: Data = Data(),
        teamAName: String = "",
        teamBName: String = ""
    ) -> StoredMatch {
        StoredMatch(
            id: id,
            date: Date(timeIntervalSince1970: 1_752_662_400),
            setScoreA: 6,
            setScoreB: 4,
            winner: "a",
            duration: duration,
            gameHistoryData: gameHistoryData,
            teamAName: teamAName,
            teamBName: teamBName
        )
    }

    private func container(at url: URL, allowsSave: Bool = true) throws -> ModelContainer {
        let config = ModelConfiguration(url: url, allowsSave: allowsSave)
        return try ModelContainer(for: StoredMatch.self, configurations: config)
    }

    /// The container the app would use as its live store in `tempDir`.
    private func liveContainer(allowsSave: Bool = true) throws -> ModelContainer {
        try container(at: tempDir.appending(path: "default.store"), allowsSave: allowsSave)
    }

    private func insert(_ matches: [StoredMatch], into modelContainer: ModelContainer) throws {
        let context = ModelContext(modelContainer)
        matches.forEach(context.insert)
        try context.save()
    }

    private func liveMatches() throws -> [StoredMatch] {
        let context = ModelContext(try liveContainer())
        return try context.fetch(FetchDescriptor<StoredMatch>())
    }

    /// Writes a real store holding `matches` at `tempDir/default.store`, then
    /// quarantines it with the real quarantine function.
    @discardableResult
    private func quarantineStore(
        with matches: [StoredMatch],
        now: Date = Date(timeIntervalSince1970: 0)
    ) throws -> URL {
        try insert(matches, into: liveContainer())
        return try XCTUnwrap(StoreRecovery.quarantine(in: tempDir, reason: "test", now: now))
    }

    /// A quarantine whose store bytes no build can read.
    @discardableResult
    private func quarantineGarbageStore(
        now: Date = Date(timeIntervalSince1970: 0)
    ) throws -> URL {
        try Data("not a database".utf8).write(to: tempDir.appending(path: "default.store"))
        return try XCTUnwrap(StoreRecovery.quarantine(in: tempDir, reason: "test", now: now))
    }

    private func fileBytes(in directory: URL) throws -> [String: Data] {
        var bytes: [String: Data] = [:]
        for name in try FileManager.default.contentsOfDirectory(atPath: directory.path) {
            bytes[name] = try Data(contentsOf: directory.appending(path: name))
        }
        return bytes
    }

    private func readableIDs(of store: QuarantinedStore) throws -> Set<UUID> {
        guard case .readable(let ids) = store.contents else {
            XCTFail("expected readable store, got \(store.contents)")
            return []
        }
        return ids
    }

    // MARK: - Listing

    func test_listing_returnsManifestDateAndMatchIDs() throws {
        let ids: Set<UUID> = [UUID(), UUID(), UUID()]
        let instant = Date(timeIntervalSince1970: 1_752_662_400)
        try quarantineStore(with: ids.map { makeMatch(id: $0) }, now: instant)

        let listed = try XCTUnwrap(StoreRecovery.listQuarantinedStores(in: tempDir).first)

        XCTAssertEqual(listed.quarantinedAt, instant)
        XCTAssertEqual(try readableIDs(of: listed), ids)
    }

    func test_listing_ignoresManifestlessAndMisnamedFolders() throws {
        // A quarantine-named folder with no manifest (contract violation)…
        let manifestless = tempDir.appending(path: "quarantined-store-orphan")
        try FileManager.default.createDirectory(at: manifestless, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: manifestless.appending(path: "default.store"))
        // …and a folder outside the naming contract entirely.
        let misnamed = tempDir.appending(path: "unrelated")
        try FileManager.default.createDirectory(at: misnamed, withIntermediateDirectories: true)

        XCTAssertTrue(StoreRecovery.listQuarantinedStores(in: tempDir).isEmpty)
    }

    func test_listing_ordersNewestFirst() throws {
        let older = try quarantineStore(with: [makeMatch()], now: Date(timeIntervalSince1970: 0))
        let newer = try quarantineStore(with: [makeMatch()], now: Date(timeIntervalSince1970: 3600))

        XCTAssertEqual(StoreRecovery.listQuarantinedStores(in: tempDir).map(\.directory),
                       [newer, older])
    }

    func test_listing_unreadableStoreListsAsUnreadable_withoutFailingTheRest() throws {
        try quarantineGarbageStore(now: Date(timeIntervalSince1970: 0))
        let readableDir = try quarantineStore(
            with: [makeMatch()], now: Date(timeIntervalSince1970: 3600))

        let listed = StoreRecovery.listQuarantinedStores(in: tempDir)

        XCTAssertEqual(listed.count, 2)
        XCTAssertEqual(listed.first?.directory, readableDir)
        if case .unreadable = try XCTUnwrap(listed.last).contents {} else {
            XCTFail("garbage store should list as unreadable")
        }
    }

    // MARK: - Restore

    func test_restore_insertsExactlyTheMissingMatches() throws {
        let shared = UUID()
        let missingA = makeMatch(gameHistoryData: Data("games".utf8))
        let missingB = makeMatch()
        let quarantine = try quarantineStore(
            with: [makeMatch(id: shared, duration: 60), missingA, missingB])
        // Played since the quarantine: same id as `shared` but different data —
        // restore must keep this version, not the quarantined one.
        try insert([makeMatch(id: shared, duration: 999), makeMatch()], into: liveContainer())

        let inserted = try StoreRecovery.restore(from: quarantine, into: liveContainer())

        XCTAssertEqual(inserted, 2)
        let live = try liveMatches()
        XCTAssertEqual(live.count, 4)
        XCTAssertEqual(live.first { $0.id == shared }?.duration, 999)
        let restored = try XCTUnwrap(live.first { $0.id == missingA.id })
        XCTAssertEqual(restored.gameHistoryData, Data("games".utf8))
        XCTAssertEqual(restored.setScoreA, 6)
        XCTAssertEqual(restored.winner, "a")
    }

    func test_restore_roundTripsTeamNamesThroughTheCopyingInitializer() throws {
        // A restore rebuilds each missing match through `init(copying:)`; the
        // Team Names must survive that copy so recovery round-trips the whole
        // record, names included.
        let named = makeMatch(teamAName: "Renan", teamBName: "Visitors")
        let quarantine = try quarantineStore(with: [named])

        XCTAssertEqual(try StoreRecovery.restore(from: quarantine, into: liveContainer()), 1)

        let restored = try XCTUnwrap(try liveMatches().first { $0.id == named.id })
        XCTAssertEqual(restored.teamAName, "Renan")
        XCTAssertEqual(restored.teamBName, "Visitors")
    }

    func test_restore_isIdempotent_secondRunInsertsNothing() throws {
        let quarantine = try quarantineStore(with: [makeMatch(), makeMatch()])

        XCTAssertEqual(try StoreRecovery.restore(from: quarantine, into: liveContainer()), 2)
        XCTAssertEqual(try StoreRecovery.restore(from: quarantine, into: liveContainer()), 0)
        XCTAssertEqual(try liveMatches().count, 2)
    }

    func test_restore_leavesQuarantineOnDisk() throws {
        let quarantine = try quarantineStore(with: [makeMatch()])
        let before = try fileBytes(in: quarantine)

        try StoreRecovery.restore(from: quarantine, into: liveContainer())

        XCTAssertEqual(try fileBytes(in: quarantine), before)
    }

    func test_failedRestore_leavesLiveStoreUntouched() throws {
        let quarantine = try quarantineStore(with: [makeMatch(), makeMatch()])
        let kept = makeMatch()
        try insert([kept], into: liveContainer())

        // A container that cannot save makes the final all-or-nothing save fail.
        XCTAssertThrowsError(
            try StoreRecovery.restore(from: quarantine, into: liveContainer(allowsSave: false)))

        let live = try liveMatches()
        XCTAssertEqual(live.map(\.id), [kept.id])
    }

    func test_listingAndFailedRestore_leaveQuarantineBytesUnchanged() throws {
        let quarantine = try quarantineStore(with: [makeMatch()])
        let before = try fileBytes(in: quarantine)

        _ = StoreRecovery.listQuarantinedStores(in: tempDir)
        _ = try? StoreRecovery.restore(from: quarantine, into: liveContainer(allowsSave: false))

        XCTAssertEqual(try fileBytes(in: quarantine), before)
    }

    // MARK: - Discard

    func test_discard_removesExactlyThatQuarantine() throws {
        let doomed = try quarantineStore(with: [makeMatch()], now: Date(timeIntervalSince1970: 0))
        let spared = try quarantineStore(
            with: [makeMatch()], now: Date(timeIntervalSince1970: 3600))
        try insert([makeMatch()], into: liveContainer())

        try StoreRecovery.discard(doomed)

        XCTAssertFalse(FileManager.default.fileExists(atPath: doomed.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: spared.path))
        XCTAssertEqual(try liveMatches().count, 1)
    }

    func test_discard_refusesAFolderOutsideTheNamingContract() throws {
        let innocent = tempDir.appending(path: "not-a-quarantine")
        try FileManager.default.createDirectory(at: innocent, withIntermediateDirectories: true)

        XCTAssertThrowsError(try StoreRecovery.discard(innocent))
        XCTAssertTrue(FileManager.default.fileExists(atPath: innocent.path))
    }
}
