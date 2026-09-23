import XCTest
@testable import BeachTennisCounter

/// The shared headline projection: one rule answers the live Placar, the Match
/// List and the Cartão with the same pair of numbers (CONTEXT.md "Headline
/// Score"). The live and stored shapes are pulled apart deliberately so each
/// side is pinned to its own inputs.
final class HeadlineScoreTests: XCTestCase {

    /// Asserts a headline by its individual fields. The tuple `(a, b, unit)`
    /// isn't `Equatable` (the `Unit` enum is not declared so); asserting the
    /// fields one at a time keeps the intent readable and compilable.
    private func assertHeadline(
        _ headline: HeadlineScore,
        a: Int,
        b: Int,
        unit: HeadlineScore.Unit,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(headline.a, a, file: file, line: line)
        XCTAssertEqual(headline.b, b, file: file, line: line)
        XCTAssertEqual(headline.unit, unit, file: file, line: line)
    }

    // MARK: - Ping pong projection (the shared core)

    func test_ping_bestOfN_withCompleteGame_showsGames() {
        let headline = HeadlineScore.pingPong(
            gamesWonA: 2, gamesWonB: 1, pointsA: 8, pointsB: 5, bestOf: 3
        )
        assertHeadline(headline, a: 2, b: 1, unit: .games)
    }

    func test_ping_bestOf1_showsPoints() {
        let headline = HeadlineScore.pingPong(
            gamesWonA: 1, gamesWonB: 0, pointsA: 11, pointsB: 9, bestOf: 1
        )
        assertHeadline(headline, a: 11, b: 9, unit: .points)
    }

    func test_ping_bestOfN_firstGameAbandoned_showsPoints() {
        let headline = HeadlineScore.pingPong(
            gamesWonA: 0, gamesWonB: 0, pointsA: 7, pointsB: 4, bestOf: 5
        )
        assertHeadline(headline, a: 7, b: 4, unit: .points)
    }

    func test_ping_missingBestOf_degeneratesToPoints() {
        let headline = HeadlineScore.pingPong(
            gamesWonA: 1, gamesWonB: 0, pointsA: 11, pointsB: 9, bestOf: 1
        )
        XCTAssertEqual(headline.unit, .points)
    }

    // MARK: - Live projection

    private func liveState(_ type: MatchType) -> MatchState {
        MatchState.newMatch(matchType: type, initialServer: .a, ruleset: .preset(for: type))
    }

    func test_live_beachTennis_showsGames() {
        var state = liveState(.beachTennis)
        state.setScoreA = 6
        state.setScoreB = 4
        let headline = HeadlineScore.live(state)
        assertHeadline(headline, a: 6, b: 4, unit: .games)
    }

    func test_live_tennis_noSetWon_showsGames() {
        var state = liveState(.tennis)
        state.setScoreA = 4
        state.setScoreB = 2
        let headline = HeadlineScore.live(state)
        assertHeadline(headline, a: 4, b: 2, unit: .games)
    }

    func test_live_tennis_withSetWon_showsSets() {
        var state = liveState(.tennis)
        state.setsWonA = 1
        state.setsWonB = 0
        let headline = HeadlineScore.live(state)
        assertHeadline(headline, a: 1, b: 0, unit: .sets)
    }

    func test_live_ping_midFirstGame_showsPoints() {
        var state = liveState(.pingPong)
        state.pingPongScore.pointsA = 7
        state.pingPongScore.pointsB = 4
        let headline = HeadlineScore.live(state)
        assertHeadline(headline, a: 7, b: 4, unit: .points)
    }

    func test_live_ping_bestOf3_afterFirstGame_showsGames() {
        var state = liveState(.pingPong)
        state.pingPongScore.gamesWonA = 1
        state.pingPongScore.gamesWonB = 0
        state.ruleset = .pingPong(PingPongRuleset(
            identifier: UUID(), name: "T", pointsTarget: 11, bestOf: 3, serveMode: .every2))
        let headline = HeadlineScore.live(state)
        assertHeadline(headline, a: 1, b: 0, unit: .games)
    }

    func test_live_ping_bestOf1_afterWinKeepsTerminalPoints() {
        var state = liveState(.pingPong)
        state.ruleset = .pingPong(.rapido)
        state.pingPongScore.gamesWonA = 1
        state.pingPongScore.pointsA = 11
        state.pingPongScore.pointsB = 9
        state.isMatchOver = true
        let headline = HeadlineScore.live(state)
        assertHeadline(headline, a: 11, b: 9, unit: .points)
    }

    // MARK: - Stored projection

    func test_stored_beachTennis_showsGames() {
        let headline = HeadlineScore.stored(
            matchType: .beachTennis, setScoreA: 6, setScoreB: 4,
            setsWonA: 0, setsWonB: 0, bestOf: nil, hasSets: false, gameHistory: [])
        assertHeadline(headline, a: 6, b: 4, unit: .games)
    }

    func test_stored_tennis_withSetWon_showsSets() {
        let headline = HeadlineScore.stored(
            matchType: .tennis, setScoreA: 3, setScoreB: 2,
            setsWonA: 2, setsWonB: 1, bestOf: nil, hasSets: true, gameHistory: [])
        assertHeadline(headline, a: 2, b: 1, unit: .sets)
    }

    func test_stored_tennis_noSetWon_showsGames() {
        let headline = HeadlineScore.stored(
            matchType: .tennis, setScoreA: 4, setScoreB: 2,
            setsWonA: 0, setsWonB: 0, bestOf: nil, hasSets: true, gameHistory: [])
        assertHeadline(headline, a: 4, b: 2, unit: .games)
    }

    func test_stored_ping_bestOf1_usesStoredPoints() {
        let headline = HeadlineScore.stored(
            matchType: .pingPong, setScoreA: 1, setScoreB: 0,
            setsWonA: 0, setsWonB: 0, bestOf: 1, hasSets: false, gameHistory: [],
            pingPointsA: 11, pingPointsB: 9)
        assertHeadline(headline, a: 11, b: 9, unit: .points)
    }

    func test_stored_ping_bestOf3_withGame_showsGames() {
        let headline = HeadlineScore.stored(
            matchType: .pingPong, setScoreA: 2, setScoreB: 1,
            setsWonA: 0, setsWonB: 0, bestOf: 3, hasSets: false, gameHistory: [],
            pingPointsA: 0, pingPointsB: 0)
        assertHeadline(headline, a: 2, b: 1, unit: .games)
    }

    func test_stored_ping_legacyRow_fallsBackToGameLogThenColumns() {
        let record = GameRecord(gameNumber: 1, setScoreA: 1, setScoreB: 0,
                                winner: .a, isTiebreak: false,
                                gameScoreDisplay: "21–19", pointsA: 21, pointsB: 19)
        let fromLog = HeadlineScore.stored(
            matchType: .pingPong, setScoreA: 1, setScoreB: 0,
            setsWonA: 0, setsWonB: 0, bestOf: 1, hasSets: false, gameHistory: [record],
            pingPointsA: nil, pingPointsB: nil)
        assertHeadline(fromLog, a: 21, b: 19, unit: .points)

        let fromColumns = HeadlineScore.stored(
            matchType: .pingPong, setScoreA: 0, setScoreB: 0,
            setsWonA: 0, setsWonB: 0, bestOf: 1, hasSets: false, gameHistory: [])
        assertHeadline(fromColumns, a: 0, b: 0, unit: .points)
    }
}