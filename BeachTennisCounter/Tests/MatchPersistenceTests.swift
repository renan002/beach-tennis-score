import XCTest
@testable import BeachTennisCounter

final class MatchPersistenceTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "MatchPersistenceTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func sampleState() -> MatchState {
        var s = MatchState()
        s.setScoreA = 3
        s.setScoreB = 2
        s.pointA = .thirty
        s.servingTeam = .b
        return s
    }

    func test_saveThenLoad_roundtripsState() {
        MatchPersistence.save(sampleState(), in: defaults)
        let loaded = MatchPersistence.load(in: defaults)
        XCTAssertEqual(loaded?.setScoreA, 3)
        XCTAssertEqual(loaded?.setScoreB, 2)
        XCTAssertEqual(loaded?.pointA, .thirty)
        XCTAssertEqual(loaded?.servingTeam, .b)
    }

    func test_load_returnsNilWhenNothingSaved() {
        XCTAssertNil(MatchPersistence.load(in: defaults))
    }

    func test_load_returnsNilWhenStale() {
        let savedAt = Date(timeIntervalSince1970: 1_000_000)
        MatchPersistence.save(sampleState(), in: defaults, now: savedAt)
        let later = savedAt.addingTimeInterval(MatchPersistence.defaultMaxAge + 1)
        XCTAssertNil(MatchPersistence.load(in: defaults, now: later))
    }

    func test_load_returnsStateJustInsideMaxAge() {
        let savedAt = Date(timeIntervalSince1970: 1_000_000)
        MatchPersistence.save(sampleState(), in: defaults, now: savedAt)
        let later = savedAt.addingTimeInterval(MatchPersistence.defaultMaxAge - 1)
        XCTAssertNotNil(MatchPersistence.load(in: defaults, now: later))
    }

    func test_save_finishedMatch_clearsInsteadOfSaving() {
        MatchPersistence.save(sampleState(), in: defaults)
        var finished = sampleState()
        finished.isMatchOver = true
        MatchPersistence.save(finished, in: defaults)
        XCTAssertNil(MatchPersistence.load(in: defaults))
    }

    func test_clear_removesSavedMatch() {
        MatchPersistence.save(sampleState(), in: defaults)
        MatchPersistence.clear(in: defaults)
        XCTAssertNil(MatchPersistence.load(in: defaults))
    }
}
