import XCTest
@testable import BeachTennisCounter

/// The iPhone history display seam: how a `StoredMatch` renders its Team Names.
/// A stored name wins; an empty one falls back to the localized "Team A"/"Team
/// B" literal, so every pre-name match reads exactly as it did before.
final class StoredMatchDisplayTests: XCTestCase {

    private func makeMatch(
        setScoreA: Int = 6,
        setScoreB: Int = 3,
        winner: String = "a",
        teamAName: String = "",
        teamBName: String = ""
    ) -> StoredMatch {
        StoredMatch(
            date: Date(),
            setScoreA: setScoreA,
            setScoreB: setScoreB,
            winner: winner,
            duration: 600,
            teamAName: teamAName,
            teamBName: teamBName
        )
    }

    func test_teamName_storedName_wins() {
        let match = makeMatch(teamAName: "Renan", teamBName: "Visitors")

        XCTAssertEqual(match.teamName(for: .a), "Renan")
        XCTAssertEqual(match.teamName(for: .b), "Visitors")
    }

    func test_teamName_emptyName_fallsBackToSlotLabel() {
        let match = makeMatch()

        XCTAssertEqual(match.teamName(for: .a), Team.a.displayName)
        XCTAssertEqual(match.teamName(for: .b), Team.b.displayName)
    }

    func test_scoreLineDisplay_flanksScoreWithNames() {
        let match = makeMatch(teamAName: "Renan", teamBName: "Visitors")

        XCTAssertEqual(match.scoreLineDisplay, "Renan \(match.scoreDisplay) Visitors")
    }

    func test_scoreLineDisplay_unnamedMatch_usesSlotLabels() {
        let match = makeMatch()

        XCTAssertEqual(
            match.scoreLineDisplay,
            "\(Team.a.displayName) \(match.scoreDisplay) \(Team.b.displayName)"
        )
    }

    func test_winnerDisplayName_namedWinner() {
        let match = makeMatch(winner: "b", teamAName: "Renan", teamBName: "Visitors")

        XCTAssertEqual(match.winnerDisplayName, "Visitors")
    }

    func test_winnerDisplayName_unnamedWinner_usesSlotLabel() {
        let match = makeMatch(winner: "a")

        XCTAssertEqual(match.winnerDisplayName, Team.a.displayName)
    }

    /// A match whose stored `winner` is not "a"/"b" (corrupt or never set) has
    /// no name to show — the badge renders empty rather than inventing a team.
    func test_winnerDisplayName_unrecognizedWinner_isEmpty() {
        let match = makeMatch(winner: "")

        XCTAssertEqual(match.winnerDisplayName, "")
    }
}
