import XCTest
@testable import BeachTennisCounter

final class TennisScoreEngineTests: XCTestCase {

    // MARK: - Helpers

    private func freshTennisState(server: Team = .a) -> MatchState {
        var s = MatchState()
        s.matchType = .tennis
        s.servingTeam = server
        s.initialServer = server
        s.tiebreakFirstServer = server
        return s
    }

    private func winGame(for team: Team, state: inout MatchState) {
        // From 0-0 (or any non-deuce start), 4 clean points win a game.
        for _ in 0..<4 { ScoreEngine.awardPoint(to: team, state: &state) }
    }

    private func winGames(_ count: Int, for team: Team, state: inout MatchState) {
        for _ in 0..<count { winGame(for: team, state: &state) }
    }

    /// Team A and B trade games until the current set is 6-6 (tiebreak active).
    private func stateAtTiebreak(server: Team = .a) -> MatchState {
        var state = freshTennisState(server: server)
        for _ in 0..<6 {
            winGames(1, for: .a, state: &state)
            winGames(1, for: .b, state: &state)
        }
        return state
    }

    // MARK: - Deuce / advantage

    func test_advantage_awardedWhenPointPlayedAtDeuce() {
        var state = freshTennisState()
        state.pointA = .forty
        state.pointB = .forty
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.advantageTeam, .a)
        XCTAssertEqual(state.setScoreA, 0)
    }

    func test_advantage_reachingDeuceByAdvancementDoesNotAward() {
        var state = freshTennisState()
        state.pointA = .forty
        state.pointB = .thirty
        ScoreEngine.awardPoint(to: .b, state: &state)
        XCTAssertEqual(state.pointB, .forty)
        XCTAssertNil(state.advantageTeam)
    }

    func test_advantage_holderWinsGame() {
        var state = freshTennisState()
        state.pointA = .forty
        state.pointB = .forty
        state.advantageTeam = .a
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.setScoreA, 1)
        XCTAssertNil(state.advantageTeam)
        XCTAssertEqual(state.pointA, .zero)
        XCTAssertEqual(state.pointB, .zero)
    }

    func test_advantage_opponentScores_backToDeuce() {
        var state = freshTennisState()
        state.pointA = .forty
        state.pointB = .forty
        state.advantageTeam = .a
        ScoreEngine.awardPoint(to: .b, state: &state)
        XCTAssertNil(state.advantageTeam)
        XCTAssertEqual(state.setScoreA, 0)
        XCTAssertEqual(state.setScoreB, 0)
        XCTAssertEqual(state.pointA, .forty)
        XCTAssertEqual(state.pointB, .forty)
    }

    func test_advantage_gameRecordShowsAd() {
        var state = freshTennisState()
        state.pointA = .forty
        state.pointB = .forty
        state.advantageTeam = .a
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.gameHistory.last?.gameScoreDisplay, "Ad")
    }

    func test_game_fortyBeatsThirty_winsGame() {
        var state = freshTennisState(server: .a)
        state.pointA = .forty
        state.pointB = .thirty
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.setScoreA, 1)
        XCTAssertEqual(state.servingTeam, .b)
    }

    // MARK: - Set progression

    func test_set_wonAtSixLove() {
        var state = freshTennisState()
        winGames(6, for: .a, state: &state)
        XCTAssertEqual(state.setsWonA, 1)
        XCTAssertEqual(state.setScoreA, 0)
        XCTAssertEqual(state.setScoreB, 0)
        XCTAssertEqual(state.setHistory.count, 1)
        XCTAssertEqual(state.setHistory[0].gamesA, 6)
        XCTAssertEqual(state.setHistory[0].gamesB, 0)
        XCTAssertFalse(state.isMatchOver)
    }

    func test_set_notWonAtSixFive() {
        var state = freshTennisState()
        for _ in 0..<5 {
            winGames(1, for: .a, state: &state)
            winGames(1, for: .b, state: &state)
        }
        winGames(1, for: .a, state: &state)
        XCTAssertEqual(state.setScoreA, 6)
        XCTAssertEqual(state.setScoreB, 5)
        XCTAssertEqual(state.setsWonA, 0)
        XCTAssertFalse(state.isTiebreak)
    }

    func test_set_wonAtSevenFive() {
        var state = freshTennisState()
        for _ in 0..<5 {
            winGames(1, for: .a, state: &state)
            winGames(1, for: .b, state: &state)
        }
        winGames(1, for: .a, state: &state) // 6-5
        winGames(1, for: .a, state: &state) // 7-5
        XCTAssertEqual(state.setsWonA, 1)
        XCTAssertEqual(state.setHistory[0].gamesA, 7)
        XCTAssertEqual(state.setHistory[0].gamesB, 5)
    }

    func test_tiebreak_startsAtSixSix() {
        var state = stateAtTiebreak()
        XCTAssertTrue(state.isTiebreak)
        XCTAssertEqual(state.setScoreA, 6)
        XCTAssertEqual(state.setScoreB, 6)
        XCTAssertFalse(state.isMatchOver)
    }

    // MARK: - Tiebreak

    func test_tiebreak_sevenZeroWinsSet() {
        var state = stateAtTiebreak()
        for _ in 0..<7 { ScoreEngine.awardPoint(to: .a, state: &state) }
        XCTAssertEqual(state.setsWonA, 1)
        XCTAssertFalse(state.isTiebreak)
        XCTAssertEqual(state.tiebreakA, 0)
        XCTAssertTrue(state.setHistory[0].isTiebreak)
        XCTAssertEqual(state.setHistory[0].gamesA, 7)
        XCTAssertEqual(state.setHistory[0].gamesB, 6)
    }

    func test_tiebreak_sevenSixDoesNotWin() {
        var state = stateAtTiebreak()
        for _ in 0..<6 { ScoreEngine.awardPoint(to: .a, state: &state) }
        for _ in 0..<6 { ScoreEngine.awardPoint(to: .b, state: &state) }
        ScoreEngine.awardPoint(to: .a, state: &state) // 7-6
        XCTAssertTrue(state.isTiebreak)
        XCTAssertEqual(state.setsWonA, 0)
    }

    func test_tiebreak_eightSixWins() {
        var state = stateAtTiebreak()
        for _ in 0..<6 { ScoreEngine.awardPoint(to: .a, state: &state) }
        for _ in 0..<6 { ScoreEngine.awardPoint(to: .b, state: &state) }
        ScoreEngine.awardPoint(to: .a, state: &state) // 7-6
        ScoreEngine.awardPoint(to: .a, state: &state) // 8-6
        XCTAssertEqual(state.setsWonA, 1)
    }

    func test_tiebreak_gameRecordScore() {
        var state = stateAtTiebreak()
        for _ in 0..<7 { ScoreEngine.awardPoint(to: .a, state: &state) }
        XCTAssertTrue(state.gameHistory.last?.isTiebreak == true)
        XCTAssertEqual(state.gameHistory.last?.gameScoreDisplay, "7–0")
    }

    func test_tiebreak_serveRotation() {
        var state = stateAtTiebreak(server: .a)
        // After 12 traded games, serve has toggled 12 times, so the tiebreak's
        // first server equals the current serving team.
        let firstServer = state.tiebreakFirstServer
        XCTAssertEqual(state.servingTeam, firstServer)
        ScoreEngine.awardPoint(to: .a, state: &state) // 1 point played
        XCTAssertEqual(state.servingTeam, firstServer.other)
        ScoreEngine.awardPoint(to: .a, state: &state) // 2
        ScoreEngine.awardPoint(to: .a, state: &state) // 3
        XCTAssertEqual(state.servingTeam, firstServer)
    }

    func test_tiebreak_nextSetServerIsOtherOfTiebreakFirstServer() {
        var state = stateAtTiebreak(server: .a)
        let firstServer = state.tiebreakFirstServer
        for _ in 0..<7 { ScoreEngine.awardPoint(to: .a, state: &state) }
        XCTAssertEqual(state.servingTeam, firstServer.other)
    }

    // MARK: - Best-of-3 match

    func test_match_twoSetsWinsMatch() {
        var state = freshTennisState()
        winGames(6, for: .a, state: &state)
        winGames(6, for: .a, state: &state)
        XCTAssertEqual(state.setsWonA, 2)
        XCTAssertTrue(state.isMatchOver)
        XCTAssertEqual(state.winner, .a)
        XCTAssertEqual(state.setHistory.count, 2)
    }

    func test_match_splitSetsGoesToThird() {
        var state = freshTennisState()
        winGames(6, for: .a, state: &state) // set 1 → A
        winGames(6, for: .b, state: &state) // set 2 → B
        XCTAssertFalse(state.isMatchOver)
        XCTAssertEqual(state.setsWonA, 1)
        XCTAssertEqual(state.setsWonB, 1)
        winGames(6, for: .a, state: &state) // set 3 → A
        XCTAssertTrue(state.isMatchOver)
        XCTAssertEqual(state.winner, .a)
    }

    func test_match_noScoringAfterMatchOver() {
        var state = freshTennisState()
        winGames(6, for: .a, state: &state)
        winGames(6, for: .a, state: &state)
        XCTAssertTrue(state.isMatchOver)
        let setsWonA = state.setsWonA
        let setScoreA = state.setScoreA
        let pointA = state.pointA
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.setsWonA, setsWonA)
        XCTAssertEqual(state.setScoreA, setScoreA)
        XCTAssertEqual(state.pointA, pointA)
    }
}
