import XCTest
@testable import BeachTennisCounter

final class PingPongScoreEngineTests: XCTestCase {

    // MARK: - Helpers

    private func newPing(
        rules: PingPongRuleset = .oficial,
        initialServer: Team = .a
    ) -> MatchState {
        MatchState.newMatch(matchType: .pingPong, initialServer: initialServer, ruleset: .pingPong(rules))
    }

    /// Alternates point-by-point until both teams sit at `n`–`n`. Each
    /// iteration awards two points (one per team), so a scoring regression
    /// cannot stall the loop; a matching score is asserted by callers.
    private func deuceReach(_ n: Int, state: inout MatchState) {
        for _ in 0..<max(n, 1) * 2 {
            let a = state.pingPoints(for: .a)
            let b = state.pingPoints(for: .b)
            if a >= n && b >= n { return }
            if a <= b {
                ScoreEngine.awardPoint(to: .a, state: &state)
                ScoreEngine.awardPoint(to: .b, state: &state)
            } else {
                ScoreEngine.awardPoint(to: .b, state: &state)
                ScoreEngine.awardPoint(to: .a, state: &state)
            }
        }
        XCTFail("deuceReach(\(n)) did not converge")
    }

    private func play(_ sequence: [Team], state: inout MatchState) {
        for team in sequence { ScoreEngine.awardPoint(to: team, state: &state) }
    }

    /// The winner reaches target−1 first and always closes with a two-point
    /// lead, so each game's point diff never threatens to not end.
    private func scoreGame(winner: Team, state: inout MatchState) {
        let target = state.ruleset.pingPong!.pointsTarget
        deuceReach(target - 1, state: &state)
        ScoreEngine.awardPoint(to: winner, state: &state)
        ScoreEngine.awardPoint(to: winner, state: &state)
    }

    private func winGames(_ count: Int, for team: Team, state: inout MatchState) {
        for _ in 0..<count { scoreGame(winner: team, state: &state) }
    }

    private func rules(
        target: Int,
        bestOf: Int,
        serveMode: PingPongServeMode
    ) -> PingPongRuleset {
        PingPongRuleset(
            identifier: UUID(),
            name: "Test",
            pointsTarget: target,
            bestOf: bestOf,
            serveMode: serveMode
        )
    }

    // MARK: - Point accumulation

    func test_pointSequence_accumulatesIntegerPoints() {
        var state = newPing()
        play([.a, .b, .a], state: &state)
        XCTAssertEqual(state.pingPoints(for: .a), 2)
        XCTAssertEqual(state.pingPoints(for: .b), 1)
        XCTAssertEqual(state.pingGamesWon(for: .a), 0)
        XCTAssertEqual(state.pingGamesWon(for: .b), 0)
    }

    // MARK: - Game end and numeric final points

    func test_gameEnd_at11_0_recordsNumericPoints() {
        var state = newPing()
        for _ in 0..<11 { ScoreEngine.awardPoint(to: .a, state: &state) }
        XCTAssertEqual(state.pingGamesWon(for: .a), 1)
        XCTAssertEqual(state.pingGamesWon(for: .b), 0)
        XCTAssertEqual(state.pingPoints(for: .a), 0)
        XCTAssertEqual(state.pingPoints(for: .b), 0)
        XCTAssertEqual(state.gameHistory.last?.pointsA, 11)
        XCTAssertEqual(state.gameHistory.last?.pointsB, 0)
        XCTAssertEqual(state.gameHistory.last?.gameScoreDisplay, "11–0")
        XCTAssertFalse(state.isMatchOver)
    }

    func test_gameEnd_deuce_12_10() {
        var state = newPing(initialServer: .a)
        deuceReach(10, state: &state)
        XCTAssertEqual(state.pingPoints(for: .a), 10)
        XCTAssertEqual(state.pingPoints(for: .b), 10)
        XCTAssertFalse(state.isMatchOver)
        play([.a], state: &state) // 11-10
        XCTAssertFalse(state.isMatchOver)
        play([.a], state: &state) // 12-10
        XCTAssertEqual(state.pingGamesWon(for: .a), 1)
        XCTAssertEqual(state.gameHistory.last?.pointsA, 12)
        XCTAssertEqual(state.gameHistory.last?.pointsB, 10)
    }

    // MARK: - Win-by-2

    func test_winBy2_11_10_doesNotWin() {
        var state = newPing()
        deuceReach(10, state: &state)
        play([.a], state: &state)
        XCTAssertFalse(state.isMatchOver)
        XCTAssertEqual(state.pingPoints(for: .a), 11)
        XCTAssertEqual(state.pingPoints(for: .b), 10)
        XCTAssertEqual(state.pingGamesWon(for: .a), 0)
    }

    func test_winBy2_12_10_wins() {
        var state = newPing()
        deuceReach(10, state: &state)
        play([.a, .a], state: &state)
        XCTAssertEqual(state.pingGamesWon(for: .a), 1)
        XCTAssertEqual(state.gameHistory.last?.pointsA, 12)
        XCTAssertEqual(state.gameHistory.last?.pointsB, 10)
    }

    func test_winBy2_20_20_needs22() {
        var state = newPing(rules: .classico)
        deuceReach(20, state: &state)
        XCTAssertEqual(state.pingPoints(for: .a), 20)
        XCTAssertEqual(state.pingPoints(for: .b), 20)
        XCTAssertFalse(state.isMatchOver)
        play([.a, .a], state: &state) // 21-20, then 22-20
        XCTAssertEqual(state.pingGamesWon(for: .a), 1)
        XCTAssertEqual(state.gameHistory.last?.pointsA, 22)
        XCTAssertEqual(state.gameHistory.last?.pointsB, 20)
    }

    func test_winBy2_custom15_interval5_runsDeuce() {
        var state = newPing(rules: rules(target: 15, bestOf: 5, serveMode: .every5), initialServer: .a)
        deuceReach(14, state: &state)
        play([.a], state: &state) // 15-14
        XCTAssertFalse(state.isMatchOver)
        play([.a], state: &state) // 16-14
        XCTAssertEqual(state.pingGamesWon(for: .a), 1)
        XCTAssertEqual(state.gameHistory.last?.pointsA, 16)
        XCTAssertEqual(state.gameHistory.last?.pointsB, 14)
    }

    /// Target 1 is legal (any positive target) and still nets the fixed
    /// win-by-2: 1–0 and 2–1 are not enough, 3–1 closes the set.
    func test_target1_needsTwoPointLead() {
        var state = newPing(rules: rules(target: 1, bestOf: 1, serveMode: .every2), initialServer: .a)
        play([.a], state: &state) // 1-0
        XCTAssertFalse(state.isMatchOver)
        play([.b, .a], state: &state) // 1-1, then 2-1
        XCTAssertFalse(state.isMatchOver)
        play([.a], state: &state) // 3-1
        XCTAssertTrue(state.isMatchOver)
        XCTAssertEqual(state.winner, .a)
        XCTAssertEqual(state.gameHistory.last?.pointsA, 3)
        XCTAssertEqual(state.gameHistory.last?.pointsB, 1)
    }

    // MARK: - Match progress (best of)

    func test_matchEnd_bestOf5_threeGames() {
        var state = newPing(rules: .oficial, initialServer: .a)
        winGames(2, for: .b, state: &state)
        winGames(1, for: .a, state: &state)
        XCTAssertFalse(state.isMatchOver)
        winGames(2, for: .a, state: &state)
        XCTAssertTrue(state.isMatchOver)
        XCTAssertEqual(state.winner, .a)
        XCTAssertEqual(state.pingGamesWon(for: .a), 3)
        XCTAssertEqual(state.pingGamesWon(for: .b), 2)
    }

    func test_matchEnd_bestOf1_singleGame() {
        var state = newPing(rules: .rapido, initialServer: .a)
        for _ in 0..<11 { ScoreEngine.awardPoint(to: .a, state: &state) }
        XCTAssertTrue(state.isMatchOver)
        XCTAssertEqual(state.winner, .a)
    }

    func test_matchEnd_bestOf3_winAt2() {
        var state = newPing(rules: .classico, initialServer: .a)
        winGames(1, for: .b, state: &state)
        winGames(2, for: .a, state: &state)
        XCTAssertTrue(state.isMatchOver)
        XCTAssertEqual(state.winner, .a)
    }

    func test_matchEnd_bestOf7_winAt4() {
        var state = newPing(rules: rules(target: 11, bestOf: 7, serveMode: .every2), initialServer: .a)
        winGames(3, for: .a, state: &state)
        winGames(1, for: .b, state: &state)
        XCTAssertFalse(state.isMatchOver)
        winGames(1, for: .a, state: &state)
        XCTAssertTrue(state.isMatchOver)
        XCTAssertEqual(state.winner, .a)
        XCTAssertEqual(state.pingGamesWon(for: .a), 4)
        XCTAssertEqual(state.pingGamesWon(for: .b), 1)
    }

    // MARK: - Terminal freeze

    func test_terminal_noFurtherScoring() {
        var state = newPing(rules: .oficial, initialServer: .a)
        winGames(3, for: .a, state: &state)
        XCTAssertTrue(state.isMatchOver)
        let games = state.pingGamesWon(for: .a)
        let points = state.pingPoints(for: .a)
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.pingGamesWon(for: .a), games)
        XCTAssertEqual(state.pingPoints(for: .a), points)
    }

    // MARK: - Nonterminal resets points

    func test_nonterminal_resetsPointsForNextGame() {
        var state = newPing(rules: .oficial, initialServer: .a)
        for _ in 0..<11 { ScoreEngine.awardPoint(to: .a, state: &state) }
        XCTAssertEqual(state.pingPoints(for: .a), 0)
        XCTAssertEqual(state.pingPoints(for: .b), 0)
        XCTAssertFalse(state.isMatchOver)
    }

    // MARK: - Game record number & score columns

    func test_gameRecord_setScoreColumnsCarryGamesWon() {
        var state = newPing(rules: .oficial, initialServer: .a)
        for _ in 0..<11 { ScoreEngine.awardPoint(to: .a, state: &state) }
        XCTAssertEqual(state.gameHistory.count, 1)
        XCTAssertEqual(state.gameHistory[0].gameNumber, 1)
        XCTAssertEqual(state.gameHistory[0].setScoreA, 1)
        XCTAssertEqual(state.gameHistory[0].setScoreB, 0)
        XCTAssertEqual(state.gameHistory[0].winner, .a)
        for _ in 0..<11 { ScoreEngine.awardPoint(to: .b, state: &state) }
        XCTAssertEqual(state.gameHistory.count, 2)
        XCTAssertEqual(state.gameHistory[1].gameNumber, 2)
        XCTAssertEqual(state.gameHistory[1].setScoreA, 1)
        XCTAssertEqual(state.gameHistory[1].setScoreB, 1)
    }

    // MARK: - newMatch stamps ruleset and initial server

    func test_newMatch_stampsRulesetAndInitialServer() {
        let state = newPing(rules: .oficial, initialServer: .b)
        XCTAssertEqual(state.ruleset.pingPong, .oficial)
        XCTAssertEqual(state.servingTeam, .b)
        XCTAssertEqual(state.pingPongScore.initialServer, .b)
        XCTAssertEqual(state.pingPongScore.gameInitialServer, .b)
    }

    func test_newMatch_defaultRuleset_isOficial() {
        let state = MatchState.newMatch(matchType: .pingPong, initialServer: .a)
        XCTAssertEqual(state.ruleset.pingPong, .oficial)
    }

    /// A fresh match given a ruleset for a different sport must not start
    /// unscorable — it falls back to the sport's preset.
    func test_newMatch_mismatchedRuleset_fallsBackToPreset() {
        let foreign = Ruleset.preset(for: .beachTennis)
        let state = MatchState.newMatch(matchType: .pingPong, initialServer: .a, ruleset: foreign)
        XCTAssertEqual(state.ruleset.pingPong, .oficial)
        XCTAssertNotEqual(state.ruleset, foreign)
    }

    // MARK: - Serve rotation, every-2 interval

    func test_every2_firstServerServesFirstTwo() {
        var state = newPing(rules: .oficial, initialServer: .a)
        XCTAssertEqual(state.servingTeam, .a)
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.servingTeam, .a)
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.servingTeam, .b)
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.servingTeam, .b)
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.servingTeam, .a)
    }

    func test_every2_deuce_alternatesEveryPoint() {
        var state = newPing(rules: .oficial, initialServer: .a)
        deuceReach(10, state: &state)
        XCTAssertEqual(state.servingTeam, .a) // 10-10: 20/2 even → first server
        ScoreEngine.awardPoint(to: .a, state: &state) // 11-10
        XCTAssertEqual(state.servingTeam, .b)
        ScoreEngine.awardPoint(to: .b, state: &state) // 11-11
        XCTAssertEqual(state.servingTeam, .a)
        ScoreEngine.awardPoint(to: .a, state: &state) // 12-11
        XCTAssertEqual(state.servingTeam, .b)
    }

    // MARK: - Serve rotation, every-5 interval

    func test_every5_firstServerServesFirstFive() {
        var state = newPing(rules: .classico, initialServer: .b)
        XCTAssertEqual(state.servingTeam, .b)
        for _ in 0..<4 {
            ScoreEngine.awardPoint(to: .a, state: &state)
            XCTAssertEqual(state.servingTeam, .b)
        }
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.servingTeam, .a)
    }

    // MARK: - Deuce parity

    func test_deuceParity_floor_at14_14_every5() {
        var state = newPing(rules: rules(target: 15, bestOf: 5, serveMode: .every5), initialServer: .a)
        deuceReach(14, state: &state)
        XCTAssertEqual(state.servingTeam, .b) // 14-14: 28/5=5 odd → other
        ScoreEngine.awardPoint(to: .a, state: &state) // 15-14
        XCTAssertEqual(state.servingTeam, .a) // 28/5+1=6 even → first
    }

    func test_deuceParity_symmetry_initialB() {
        var state = newPing(rules: rules(target: 15, bestOf: 5, serveMode: .every5), initialServer: .b)
        deuceReach(14, state: &state)
        XCTAssertEqual(state.servingTeam, .a)
        ScoreEngine.awardPoint(to: .a, state: &state) // 15-14
        XCTAssertEqual(state.servingTeam, .b)
    }

    /// 20–20 in a 21-point set: the serve keeps alternating every point after it.
    func test_deuceParity_20_20_alternatesEveryPoint() {
        var state = newPing(rules: .classico, initialServer: .a)
        deuceReach(20, state: &state)
        XCTAssertEqual(state.servingTeam, .a) // 40/5=8 even → first
        ScoreEngine.awardPoint(to: .a, state: &state) // 21-20
        XCTAssertEqual(state.servingTeam, .b)
        ScoreEngine.awardPoint(to: .b, state: &state) // 21-21
        XCTAssertEqual(state.servingTeam, .a)
        ScoreEngine.awardPoint(to: .a, state: &state) // 22-21
        XCTAssertEqual(state.servingTeam, .b)
    }

    // MARK: - Serve rotation, rally

    func test_rally_lastScorerServes() {
        var state = newPing(rules: rules(target: 11, bestOf: 5, serveMode: .rally), initialServer: .a)
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.servingTeam, .a)
        ScoreEngine.awardPoint(to: .b, state: &state)
        XCTAssertEqual(state.servingTeam, .b)
        ScoreEngine.awardPoint(to: .b, state: &state)
        XCTAssertEqual(state.servingTeam, .b)
    }

    /// At deuce, rally serve still tracks the last scorer, not an interval. B
    /// scoring twice in a row (11-11 then 11-12) keeps B serving — and the
    /// match is not over because the lead is still one, not two.
    func test_rally_deuce_sameScorerTwice_keepsServing() {
        var state = newPing(rules: rules(target: 11, bestOf: 5, serveMode: .rally), initialServer: .a)
        deuceReach(10, state: &state)
        play([.a, .b, .b], state: &state) // 11-10, 11-11, 11-12
        XCTAssertEqual(state.servingTeam, .b)
        XCTAssertFalse(state.isMatchOver)
    }

    func test_rally_nextGameLastScorerServes() {
        var state = newPing(rules: rules(target: 11, bestOf: 5, serveMode: .rally), initialServer: .a)
        deuceReach(9, state: &state)
        play([.b, .b], state: &state) // B finishes 11-9
        XCTAssertEqual(state.pingGamesWon(for: .b), 1)
        XCTAssertEqual(state.gameHistory.last?.pointsA, 9)
        XCTAssertEqual(state.gameHistory.last?.pointsB, 11)
        XCTAssertEqual(state.servingTeam, .b)
        XCTAssertEqual(state.pingPongScore.gameInitialServer, .b)
    }

    // MARK: - Game-change serve alternation (interval modes)

    func test_every2_nextGameAlternatesServer() {
        var state = newPing(rules: .oficial, initialServer: .a)
        for _ in 0..<11 { ScoreEngine.awardPoint(to: .a, state: &state) }
        XCTAssertEqual(state.pingPongScore.gameInitialServer, .b)
        XCTAssertEqual(state.servingTeam, .b)
        for _ in 0..<11 { ScoreEngine.awardPoint(to: .b, state: &state) }
        XCTAssertEqual(state.pingPongScore.gameInitialServer, .a)
        XCTAssertEqual(state.servingTeam, .a)
    }

    // MARK: - Restore (Codable)

    func test_restore_roundTripsPingStateExact() throws {
        var state = newPing(rules: rules(target: 15, bestOf: 5, serveMode: .every5), initialServer: .b)
        deuceReach(14, state: &state)
        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(MatchState.self, from: data)
        XCTAssertEqual(restored, state)
        XCTAssertEqual(restored.pingPoints(for: .a), 14)
        XCTAssertEqual(restored.pingPoints(for: .b), 14)
        XCTAssertEqual(restored.pingPongScore.gameInitialServer, .b)
        XCTAssertEqual(restored.ruleset, state.ruleset)
    }

    func test_restore_pingMatchMissingPingPayload_rejects() throws {
        var state = newPing(rules: .oficial, initialServer: .a)
        state.pingPongScore.pointsA = 9
        let data = try JSONEncoder().encode(state)
        var obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        obj.removeValue(forKey: "pingPongScore")
        let stripped = try JSONSerialization.data(withJSONObject: obj)
        XCTAssertThrowsError(try JSONDecoder().decode(MatchState.self, from: stripped))
    }

    func test_restore_pingMatchMissingRuleset_rejects() throws {
        var state = newPing(rules: .oficial, initialServer: .a)
        let data = try JSONEncoder().encode(state)
        var obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        obj.removeValue(forKey: "ruleset")
        let stripped = try JSONSerialization.data(withJSONObject: obj)
        XCTAssertThrowsError(try JSONDecoder().decode(MatchState.self, from: stripped))
    }

    /// A stored beach match encoded before ping pong existed (no pingPongScore
    /// key, no ruleset) must decode with defaults, and beach scoring intact.
    func test_restore_legacyMatchDecodes() throws {
        var state = MatchState.newMatch(matchType: .beachTennis, initialServer: .a)
        ScoreEngine.awardPoint(to: .a, state: &state)
        let data = try JSONEncoder().encode(state)
        var obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        obj.removeValue(forKey: "pingPongScore")
        obj.removeValue(forKey: "ruleset")
        let stripped = try JSONSerialization.data(withJSONObject: obj)
        let restored = try JSONDecoder().decode(MatchState.self, from: stripped)
        XCTAssertEqual(restored.point(for: .a), .fifteen)
        XCTAssertEqual(restored.matchType, .beachTennis)
        XCTAssertEqual(restored.pingPongScore, PingPongState(initialServer: .a))
        XCTAssertEqual(restored.ruleset.sport, .beachTennis)
    }

    /// A ruleset for the wrong sport stored on a match is malformed.
    func test_restore_mismatchedRuleset_rejects() throws {
        var state = newPing(rules: .oficial, initialServer: .a)
        state.ruleset = Ruleset.preset(for: .beachTennis)
        let data = try JSONEncoder().encode(state)
        XCTAssertThrowsError(try JSONDecoder().decode(MatchState.self, from: data))
    }

    /// Negative counters in a stored ping state are malformed data.
    func test_restore_negativeCounters_reject() throws {
        var state = newPing(rules: .oficial, initialServer: .a)
        state.pingPongScore.pointsA = -1
        let data = try JSONEncoder().encode(state)
        XCTAssertThrowsError(try JSONDecoder().decode(MatchState.self, from: data))
    }

    func test_match_withoutPingRules_isNotScorable() {
        var state = MatchState.newMatch(matchType: .pingPong, initialServer: .a)
        state.ruleset = Ruleset.preset(for: .beachTennis)
        ScoreEngine.awardPoint(to: .a, state: &state)
        XCTAssertEqual(state.pingPoints(for: .a), 0)
    }

    // MARK: - Undo across a nonterminal game

    /// Undo restores the previous MatchState whole — points, games, server, and
    /// the GameRecord list — for a point inside a game that hasn't ended.
    func test_undo_acrossNonterminalGame_restoresWholeState() {
        var match = MatchInProgress(state: MatchState.newMatch(matchType: .pingPong, initialServer: .a, ruleset: .pingPong(.oficial)))

        // Close game 1 for A, so game 2 starts with A on 1 game and B serving.
        for _ in 0..<11 { _ = match.awardPoint(to: .a) }
        XCTAssertEqual(match.state.pingGamesWon(for: .a), 1)
        XCTAssertEqual(match.state.gameHistory.count, 1)
        XCTAssertEqual(match.state.pingPongScore.gameInitialServer, .b)

        // Two points into game 2, then undo them both.
        _ = match.awardPoint(to: .b)
        _ = match.awardPoint(to: .b)
        XCTAssertEqual(match.state.pingPoints(for: .b), 2)
        _ = match.undo()
        XCTAssertEqual(match.state.pingPoints(for: .b), 1)
        _ = match.undo()

        // Back at the fresh game-2 board: game 1 recorded, rotation intact.
        XCTAssertEqual(match.state.pingPoints(for: .a), 0)
        XCTAssertEqual(match.state.pingPoints(for: .b), 0)
        XCTAssertEqual(match.state.pingGamesWon(for: .a), 1)
        XCTAssertEqual(match.state.gameHistory.count, 1)
        XCTAssertEqual(match.state.pingPongScore.gameInitialServer, .b)
        XCTAssertEqual(match.state.servingTeam, .b)
    }
}