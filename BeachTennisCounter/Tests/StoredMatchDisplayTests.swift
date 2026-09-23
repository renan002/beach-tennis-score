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
        teamBName: String = "",
        matchTypeRaw: String = "beachTennis",
        rulesetData: Data = Data(),
        gameHistoryData: Data = Data(),
        pingPointsA: Int? = nil,
        pingPointsB: Int? = nil
    ) -> StoredMatch {
        StoredMatch(
            date: Date(),
            setScoreA: setScoreA,
            setScoreB: setScoreB,
            winner: winner,
            duration: 600,
            gameHistoryData: gameHistoryData,
            matchTypeRaw: matchTypeRaw,
            teamAName: teamAName,
            teamBName: teamBName,
            rulesetData: rulesetData,
            pingPointsA: pingPointsA,
            pingPointsB: pingPointsB
        )
    }

    private func pingRulesetData(bestOf: Int, name: String = "Test") -> Data {
        let rules = Ruleset.pingPong(PingPongRuleset(
            identifier: UUID(),
            name: name,
            pointsTarget: 11,
            bestOf: bestOf,
            serveMode: .every2
        ))
        return (try? JSONEncoder().encode(rules)) ?? Data()
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

    // MARK: - Ping pong headline projection

    /// A finished best-of-1 (Rápido) match: the flat columns carry the 1–0
    /// games-won count, but the headline must show the terminal numeric points
    /// from the second-tier storage fields — 11–9, never a bare 1–0.
    func test_ping_bestOf1_finished_showsTerminalPoints() {
        let match = makeMatch(
            setScoreA: 1,
            setScoreB: 0,
            winner: "a",
            matchTypeRaw: MatchType.pingPong.rawValue,
            rulesetData: pingRulesetData(bestOf: 1),
            pingPointsA: 11,
            pingPointsB: 9
        )

        XCTAssertEqual(match.scoreDisplay, "11 – 9")
    }

    /// A best-of-1 match abandoned mid-game: points never reached the terminal
    /// pair, so the headline falls back to the stored points (a first-game
    /// abandonment with no stored pair shows what it died at — here 0-0).
    func test_ping_bestOf1_firstGameAbandonment_showsPoints() {
        let match = makeMatch(
            setScoreA: 0,
            setScoreB: 0,
            matchTypeRaw: MatchType.pingPong.rawValue,
            rulesetData: pingRulesetData(bestOf: 1)
        )

        XCTAssertEqual(match.scoreDisplay, "0 – 0")
    }

    /// A best-of-3 match with a complete game on the board shows games won —
    /// 1–0 — even though the stored points would say something else.
    func test_ping_bestOf3_withCompleteGame_showsGames() {
        let match = makeMatch(
            setScoreA: 1,
            setScoreB: 0,
            winner: "a",
            matchTypeRaw: MatchType.pingPong.rawValue,
            rulesetData: pingRulesetData(bestOf: 3),
            pingPointsA: 0,
            pingPointsB: 0
        )

        XCTAssertEqual(match.scoreDisplay, "1 – 0")
    }

    /// A best-of-1 match without the second-tier storage (a pre-feature row):
    /// the headline falls back to the terminal game's numeric record.
    func test_ping_bestOf1_legacyRow_fallsBackToGameLogPoints() {
        let record = GameRecord(gameNumber: 1, setScoreA: 1, setScoreB: 0,
                                winner: .a, isTiebreak: false,
                                gameScoreDisplay: "11–9", pointsA: 11, pointsB: 9)
        let match = makeMatch(
            matchTypeRaw: MatchType.pingPong.rawValue,
            rulesetData: pingRulesetData(bestOf: 1),
            gameHistoryData: (try? JSONEncoder().encode([record])) ?? Data()
        )

        XCTAssertEqual(match.scoreDisplay, "11 – 9")
    }
}
