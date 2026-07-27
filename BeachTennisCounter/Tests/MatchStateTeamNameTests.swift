import XCTest
@testable import BeachTennisCounter

/// The `MatchState.teamName(for:)` resolver as a pure function: a non-empty name
/// wins, an empty name falls back to the localized `Team.displayName`. Display
/// sites call this resolver, never `displayName` directly.
final class MatchStateTeamNameTests: XCTestCase {

    func test_teamName_nonEmptyName_wins() {
        var state = MatchState()
        state.teamAName = "Renan"
        state.teamBName = "Visitors"
        XCTAssertEqual(state.teamName(for: .a), "Renan")
        XCTAssertEqual(state.teamName(for: .b), "Visitors")
    }

    func test_teamName_emptyName_fallsBackToDisplayName() {
        let state = MatchState() // names default to ""
        XCTAssertEqual(state.teamName(for: .a), Team.a.displayName)
        XCTAssertEqual(state.teamName(for: .b), Team.b.displayName)
    }

    func test_teamName_resolvesEachSideIndependently() {
        var state = MatchState()
        state.teamAName = "Renan"
        // B left empty falls back while A resolves to its name.
        XCTAssertEqual(state.teamName(for: .a), "Renan")
        XCTAssertEqual(state.teamName(for: .b), Team.b.displayName)
    }

    func test_teamNames_defaultEmpty() {
        let state = MatchState()
        XCTAssertEqual(state.teamAName, "")
        XCTAssertEqual(state.teamBName, "")
    }

    // MARK: - newMatch stamps names at match start (#88)

    func test_newMatch_stampsSyncedNames() {
        let state = MatchState.newMatch(
            matchType: .beachTennis,
            initialServer: .b,
            teamAName: "Renan",
            teamBName: "Bruno"
        )
        XCTAssertEqual(state.teamAName, "Renan")
        XCTAssertEqual(state.teamBName, "Bruno")
        // Serve wiring preserved alongside the names.
        XCTAssertEqual(state.initialServer, .b)
        XCTAssertEqual(state.servingTeam, .b)
        XCTAssertEqual(state.tiebreakFirstServer, .b)
        XCTAssertEqual(state.matchType, .beachTennis)
    }

    func test_newMatch_noNames_defaultsEmpty() {
        let state = MatchState.newMatch(matchType: .tennis, initialServer: .a)
        XCTAssertEqual(state.teamAName, "")
        XCTAssertEqual(state.teamBName, "")
        // Empty names resolve to the localized fallback labels.
        XCTAssertEqual(state.teamName(for: .a), Team.a.displayName)
        XCTAssertEqual(state.teamName(for: .b), Team.b.displayName)
    }

    // MARK: - History immutability: stamped names survive persistence round-trip

    func test_stampedNames_surviveScoringAndUndo() {
        var state = MatchState.newMatch(
            matchType: .beachTennis,
            initialServer: .a,
            teamAName: "Renan",
            teamBName: "Bruno"
        )
        // The undo stack snapshots the whole struct before each point.
        let snapshot = state
        ScoreEngine.awardPoint(to: .a, state: &state)
        // Scoring must not disturb the stamped names.
        XCTAssertEqual(state.teamAName, "Renan")
        XCTAssertEqual(state.teamBName, "Bruno")
        // Undo restores the prior snapshot, names intact.
        state = snapshot
        XCTAssertEqual(state.teamAName, "Renan")
        XCTAssertEqual(state.teamBName, "Bruno")
    }

    func test_stampedNames_survivePersistenceRoundTrip() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let state = MatchState.newMatch(
            matchType: .beachTennis,
            initialServer: .a,
            teamAName: "Renan",
            teamBName: "Bruno"
        )
        MatchPersistence.save(state, in: defaults)
        let restored = MatchPersistence.load(in: defaults)
        XCTAssertEqual(restored?.teamAName, "Renan")
        XCTAssertEqual(restored?.teamBName, "Bruno")
    }
}
