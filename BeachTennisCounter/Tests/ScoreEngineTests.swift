import XCTest
@testable import BeachTennisCounter

final class ScoreEngineTests: XCTestCase {

    // MARK: - Helpers

    private func freshState(server: Team = .a) -> MatchState {
        var s = MatchState()
        s.servingTeam = server
        s.initialServer = server
        return s
    }

    private func winGame(for team: Team, state: inout MatchState) {
        for _ in 0..<4 {
            ScoreEngine.awardPoint(to: team, state: &state)
        }
    }

    private func winGames(_ count: Int, for team: Team, state: inout MatchState) {
        for _ in 0..<count { winGame(for: team, state: &state) }
    }

    private func stateAt6_6() -> MatchState {
        var state = freshState()
        for _ in 0..<6 {
            winGames(1, for: .a, state: &state)
            winGames(1, for: .b, state: &state)
        }
        return state
    }

    // MARK: - Point progression

    func test_pointProgression_zeroToFifteen() {
        var state = freshState()
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.pointA, .fifteen)
        XCTAssertEqual(state.pointB, .zero)
    }

    func test_pointProgression_fifteenToThirty() {
        var state = freshState()
        state.pointA = .fifteen
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.pointA, .thirty)
    }

    func test_pointProgression_thirtyToForty() {
        var state = freshState()
        state.pointA = .thirty
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.pointA, .forty)
    }

    func test_pointProgression_fortyWinsGame() {
        var state = freshState()
        state.pointA = .forty
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.setScoreA, 1)
        XCTAssertEqual(state.pointA, .zero)
        XCTAssertEqual(state.pointB, .zero)
    }

    // MARK: - Golden point

    func test_goldenPoint_flagSetWhenAReaches40at4040() {
        var state = freshState()
        state.pointA = .thirty
        state.pointB = .forty
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertTrue(state.isGoldenPoint)
    }

    func test_goldenPoint_flagSetWhenBReaches40at4040() {
        var state = freshState()
        state.pointA = .forty
        state.pointB = .thirty
        ScoreEngine.awardPoint(to: .b, state: &state)
        XCTAssertTrue(state.isGoldenPoint)
    }

    func test_goldenPoint_winsGameForA() {
        var state = freshState()
        state.isGoldenPoint = true
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.setScoreA, 1)
        XCTAssertFalse(state.isGoldenPoint)
    }

    func test_goldenPoint_winsGameForB() {
        var state = freshState()
        state.isGoldenPoint = true
        ScoreEngine.awardPoint(to: .b, state: &state)
        XCTAssertEqual(state.setScoreB, 1)
        XCTAssertFalse(state.isGoldenPoint)
    }

    func test_goldenPoint_gameRecordShowsGP() {
        var state = freshState()
        state.isGoldenPoint = true
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.gameHistory.last?.gameScoreDisplay, "GP")
    }

    // MARK: - Win game side effects

    func test_winGame_resetsPoints() {
        var state = freshState()
        state.pointA = .forty
        state.pointB = .thirty
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.pointA, .zero)
        XCTAssertEqual(state.pointB, .zero)
    }

    func test_winGame_rotatesServe() {
        var state = freshState(server: .a)
        state.pointA = .forty
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.servingTeam, .b)
    }

    func test_winGame_appendsGameRecord() {
        var state = freshState()
        state.pointA = .forty
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.gameHistory.count, 1)
        XCTAssertEqual(state.gameHistory[0].winner, .a)
        XCTAssertFalse(state.gameHistory[0].isTiebreak)
    }

    func test_winGame_gameRecordShowsScore() {
        var state = freshState()
        state.pointA = .forty
        state.pointB = .thirty
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.gameHistory[0].gameScoreDisplay, "40–30")
    }

    // MARK: - Match win conditions

    func test_matchWin_sixZero() {
        var state = freshState()
        winGames(6, for: .a, state: &state)
        XCTAssertTrue(state.isMatchOver)
        XCTAssertEqual(state.winner, .a)
        XCTAssertEqual(state.setScoreA, 6)
        XCTAssertEqual(state.setScoreB, 0)
    }

    func test_matchWin_sixFour() {
        var state = freshState()
        for _ in 0..<4 {
            winGames(1, for: .b, state: &state)
            winGames(1, for: .a, state: &state)
        }
        winGames(2, for: .a, state: &state)
        XCTAssertTrue(state.isMatchOver)
        XCTAssertEqual(state.winner, .a)
        XCTAssertEqual(state.setScoreA, 6)
        XCTAssertEqual(state.setScoreB, 4)
    }

    func test_matchWin_sevenFive() {
        var state = freshState()
        for _ in 0..<5 {
            winGames(1, for: .a, state: &state)
            winGames(1, for: .b, state: &state)
        }
        XCTAssertFalse(state.isMatchOver)
        winGames(2, for: .a, state: &state)
        XCTAssertTrue(state.isMatchOver)
        XCTAssertEqual(state.winner, .a)
        XCTAssertEqual(state.setScoreA, 7)
        XCTAssertEqual(state.setScoreB, 5)
    }

    func test_noMatchEnd_atFiveFive() {
        var state = freshState()
        for _ in 0..<5 {
            winGames(1, for: .a, state: &state)
            winGames(1, for: .b, state: &state)
        }
        XCTAssertFalse(state.isMatchOver)
        XCTAssertFalse(state.isTiebreak)
        XCTAssertEqual(state.setScoreA, 5)
        XCTAssertEqual(state.setScoreB, 5)
    }

    func test_noMatchEnd_atSixFive() {
        var state = freshState()
        for _ in 0..<5 {
            winGames(1, for: .a, state: &state)
            winGames(1, for: .b, state: &state)
        }
        winGames(1, for: .a, state: &state)
        XCTAssertFalse(state.isMatchOver)
        XCTAssertFalse(state.isTiebreak)
        XCTAssertEqual(state.setScoreA, 6)
        XCTAssertEqual(state.setScoreB, 5)
    }

    // MARK: - Tiebreak

    func test_tiebreak_triggeredAtSixSix() {
        var state = stateAt6_6()
        XCTAssertTrue(state.isTiebreak)
        XCTAssertFalse(state.isMatchOver)
        XCTAssertEqual(state.setScoreA, 6)
        XCTAssertEqual(state.setScoreB, 6)
    }

    func test_tiebreak_winAtSevenZero() {
        var state = stateAt6_6()
        for _ in 0..<7 { ScoreEngine.awardPoint(to: .a, state: &state) }
        XCTAssertTrue(state.isMatchOver)
        XCTAssertEqual(state.winner, .a)
        XCTAssertEqual(state.setScoreA, 7)
        XCTAssertEqual(state.setScoreB, 6)
    }

    func test_tiebreak_winAtSevenFive() {
        var state = stateAt6_6()
        for _ in 0..<5 { ScoreEngine.awardPoint(to: .b, state: &state) }
        for _ in 0..<7 { ScoreEngine.awardPoint(to: .a, state: &state) }
        XCTAssertTrue(state.isMatchOver)
        XCTAssertEqual(state.winner, .a)
        XCTAssertEqual(state.tiebreakA, 7)
        XCTAssertEqual(state.tiebreakB, 5)
    }

    func test_tiebreak_appendsGameRecord() {
        var state = stateAt6_6()
        for _ in 0..<7 { ScoreEngine.awardPoint(to: .a, state: &state) }
        XCTAssertTrue(state.gameHistory.last?.isTiebreak == true)
        XCTAssertEqual(state.gameHistory.last?.gameScoreDisplay, "7–0")
        XCTAssertEqual(state.gameHistory.last?.winner, .a)
    }

    func test_tiebreak_noPointsAfterMatchOver() {
        var state = stateAt6_6()
        for _ in 0..<7 { ScoreEngine.awardPoint(to: .a, state: &state) }
        let tiebreakA = state.tiebreakA
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.tiebreakA, tiebreakA)
    }

    func test_tiebreak_sevenSixDoesNotWin() {
        var state = stateAt6_6()
        for _ in 0..<6 { ScoreEngine.awardPoint(to: .a, state: &state) }
        for _ in 0..<6 { ScoreEngine.awardPoint(to: .b, state: &state) }
        ScoreEngine.awardPoint(to: .a, state: &state) // 7-6
        XCTAssertFalse(state.isMatchOver)
        XCTAssertTrue(state.isTiebreak)
        XCTAssertEqual(state.tiebreakA, 7)
        XCTAssertEqual(state.tiebreakB, 6)
    }

    func test_tiebreak_eightSixWins() {
        var state = stateAt6_6()
        for _ in 0..<6 { ScoreEngine.awardPoint(to: .a, state: &state) }
        for _ in 0..<6 { ScoreEngine.awardPoint(to: .b, state: &state) }
        ScoreEngine.awardPoint(to: .a, state: &state) // 7-6
        ScoreEngine.awardPoint(to: .a, state: &state) // 8-6
        XCTAssertTrue(state.isMatchOver)
        XCTAssertEqual(state.winner, .a)
        XCTAssertEqual(state.gameHistory.last?.gameScoreDisplay, "8–6")
    }

    func test_tiebreak_winByTwoSymmetricForB() {
        var state = stateAt6_6()
        for _ in 0..<6 { ScoreEngine.awardPoint(to: .b, state: &state) }
        for _ in 0..<6 { ScoreEngine.awardPoint(to: .a, state: &state) }
        ScoreEngine.awardPoint(to: .b, state: &state) // 6-7
        XCTAssertFalse(state.isMatchOver)
        ScoreEngine.awardPoint(to: .b, state: &state) // 6-8
        XCTAssertTrue(state.isMatchOver)
        XCTAssertEqual(state.winner, .b)
    }

    // MARK: - Match over guard

    func test_matchOver_noFurtherScoringAllowed() {
        var state = freshState()
        winGames(6, for: .a, state: &state)
        XCTAssertTrue(state.isMatchOver)
        let scoreBefore = state.setScoreA
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.setScoreA, scoreBefore)
    }

    // MARK: - Tiebreak serve rotation

    func test_tiebreakServer_point0_firstServerServes() {
        XCTAssertEqual(ScoreEngine.tiebreakServer(pointsPlayed: 0, firstServer: .a), .a)
    }

    func test_tiebreakServer_point1_otherServes() {
        XCTAssertEqual(ScoreEngine.tiebreakServer(pointsPlayed: 1, firstServer: .a), .b)
    }

    func test_tiebreakServer_point2_otherServes() {
        XCTAssertEqual(ScoreEngine.tiebreakServer(pointsPlayed: 2, firstServer: .a), .b)
    }

    func test_tiebreakServer_point3_firstServes() {
        XCTAssertEqual(ScoreEngine.tiebreakServer(pointsPlayed: 3, firstServer: .a), .a)
    }

    func test_tiebreakServer_point4_firstServes() {
        XCTAssertEqual(ScoreEngine.tiebreakServer(pointsPlayed: 4, firstServer: .a), .a)
    }

    func test_tiebreakServer_point5_otherServes() {
        XCTAssertEqual(ScoreEngine.tiebreakServer(pointsPlayed: 5, firstServer: .a), .b)
    }

    func test_tiebreakServer_symmetry_withBAsFirst() {
        XCTAssertEqual(ScoreEngine.tiebreakServer(pointsPlayed: 0, firstServer: .b), .b)
        XCTAssertEqual(ScoreEngine.tiebreakServer(pointsPlayed: 1, firstServer: .b), .a)
        XCTAssertEqual(ScoreEngine.tiebreakServer(pointsPlayed: 3, firstServer: .b), .b)
    }
}
