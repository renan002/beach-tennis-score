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
}
