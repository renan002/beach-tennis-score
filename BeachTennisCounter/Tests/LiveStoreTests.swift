import XCTest
import SwiftData
@testable import BeachTennisCounter

/// Exercises the store-opening seam (`LiveStore.open(in:)`) through external
/// behaviour only: given a directory, what container comes back and what is on
/// disk afterwards. No assertions on private state or call order.
final class LiveStoreTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func fetchMatches(_ container: ModelContainer) throws -> [StoredMatch] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<StoredMatch>(sortBy: [SortDescriptor(\.date)]))
    }

    private func quarantineDirs() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix("quarantined-store-") }
    }

    // MARK: - Fresh start

    func test_emptyDirectory_opensFreshEmptyStore_noQuarantine() throws {
        let container = LiveStore.open(in: dir)

        XCTAssertTrue(try fetchMatches(container).isEmpty)
        XCTAssertTrue(try quarantineDirs().isEmpty)
    }

    // MARK: - Migration from 1.1.x

    func test_legacyStore_migratesMatchesIntact_withBeachDefaults_noQuarantine() throws {
        let matchA = LegacyMatch(
            id: UUID(), date: Date(timeIntervalSince1970: 1_000_000),
            setScoreA: 6, setScoreB: 4, winner: Team.a.rawValue, duration: 1830)
        let matchB = LegacyMatch(
            id: UUID(), date: Date(timeIntervalSince1970: 2_000_000),
            setScoreA: 3, setScoreB: 6, winner: Team.b.rawValue, duration: 2415)
        try LegacyStore.write([matchA, matchB], to: dir)

        let container = LiveStore.open(in: dir)

        // Every match survives the migration, in order, with its original data.
        let matches = try fetchMatches(container)
        XCTAssertEqual(matches.map(\.id), [matchA.id, matchB.id])
        XCTAssertEqual(matches.map(\.setScoreA), [6, 3])
        XCTAssertEqual(matches.map(\.setScoreB), [4, 6])
        XCTAssertEqual(matches.map(\.winner), [Team.a.rawValue, Team.b.rawValue])
        XCTAssertEqual(matches.map(\.duration), [1830, 2415])

        // The Tennis-mode fields never misrepresent an old match: zero sets
        // won, beach tennis type.
        XCTAssertEqual(matches.map(\.setsWonA), [0, 0])
        XCTAssertEqual(matches.map(\.setsWonB), [0, 0])
        XCTAssertEqual(matches.map(\.matchType), [.beachTennis, .beachTennis])

        // A store written without the Team Name attributes migrates in place:
        // its rows materialize empty names, never nil or a failed open.
        XCTAssertEqual(matches.map(\.teamAName), ["", ""])
        XCTAssertEqual(matches.map(\.teamBName), ["", ""])

        // A store that opens is never quarantined.
        XCTAssertTrue(try quarantineDirs().isEmpty)
    }

    // MARK: - Unopenable store

    func test_unopenableStore_isQuarantinedNotDeleted_andOpensFresh() throws {
        let garbage = Data("this is not a SQLite database".utf8)
        try garbage.write(to: dir.appending(path: LiveStore.storeName))

        let container = LiveStore.open(in: dir)

        // The app still launches ready to score, on a fresh empty store.
        XCTAssertTrue(try fetchMatches(container).isEmpty)

        // The unopenable store is set aside intact — moved, never deleted — so
        // a later Restore can bring it back.
        let quarantines = try quarantineDirs()
        XCTAssertEqual(quarantines.count, 1)
        let quarantined = dir.appending(path: quarantines[0]).appending(path: LiveStore.storeName)
        XCTAssertEqual(try Data(contentsOf: quarantined), garbage)
    }
}
