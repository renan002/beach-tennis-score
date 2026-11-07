import XCTest
@testable import BeachTennisCounter

final class BeachTennisRulesetTests: XCTestCase {

    // MARK: - Helpers

    private func rules(
        format: BeachMatchFormat = .firstTo,
        sets: Int = 6,
        winByTwoSets: Bool = true,
        tiebreak: Bool = true,
        tiebreakPoints: Int = 7,
        tiebreakWinByTwo: Bool = true,
        deuceRule: BeachDeuceRule = .goldenPoint
    ) -> BeachTennisRuleset {
        BeachTennisRuleset(
            identifier: UUID(), name: "Test", format: format, sets: sets,
            winByTwoSets: winByTwoSets, tiebreak: tiebreak, tiebreakPoints: tiebreakPoints,
            tiebreakWinByTwo: tiebreakWinByTwo, deuceRule: deuceRule
        )
    }

    private func newBeach(_ r: BeachTennisRuleset = .padrao) -> MatchState {
        MatchState.newMatch(matchType: .beachTennis, initialServer: .a, ruleset: .beachTennis(r))
    }

    /// A game won to love: four straight points.
    private func winGame(_ team: Team, _ state: inout MatchState) {
        for _ in 0..<4 { ScoreEngine.awardPoint(to: team, state: &state) }
    }

    private func games(_ sequence: [Team], _ state: inout MatchState) {
        for team in sequence { winGame(team, &state) }
    }

    /// Reaches `a`–`b` in Sets by alternating, then finishing the leader's run.
    private func reach(_ a: Int, _ b: Int, _ state: inout MatchState) {
        let level = min(a, b)
        for _ in 0..<level { games([.a, .b], &state) }
        for _ in level..<a { winGame(.a, &state) }
        for _ in level..<b { winGame(.b, &state) }
    }

    private func points(_ team: Team, _ n: Int, _ state: inout MatchState) {
        for _ in 0..<n { ScoreEngine.awardPoint(to: team, state: &state) }
    }

    // MARK: - Padrão is today's rules

    func test_padrao_6_4_wins() {
        var s = newBeach()
        reach(6, 4, &s)
        XCTAssertTrue(s.isMatchOver)
        XCTAssertEqual(s.winner, .a)
    }

    func test_padrao_6_5_continues_7_5_wins() {
        var s = newBeach()
        reach(5, 5, &s)
        winGame(.a, &s)
        XCTAssertFalse(s.isMatchOver)
        winGame(.a, &s)
        XCTAssertTrue(s.isMatchOver)
        XCTAssertEqual(s.setScoreA, 7)
        XCTAssertEqual(s.setScoreB, 5)
    }

    func test_padrao_6_6_tiebreak_needsTwoPointLead() {
        var s = newBeach()
        reach(6, 6, &s)
        XCTAssertTrue(s.isTiebreak)
        XCTAssertFalse(s.isMatchOver)
        points(.a, 6, &s)
        points(.b, 6, &s)
        points(.a, 1, &s)        // 7–6
        XCTAssertFalse(s.isMatchOver)
        points(.a, 1, &s)        // 8–6
        XCTAssertTrue(s.isMatchOver)
        XCTAssertEqual(s.winner, .a)
        XCTAssertEqual(s.setScoreA, 7)
        XCTAssertEqual(s.setScoreB, 6)
        XCTAssertEqual(s.gameHistory.last?.isTiebreak, true)
        XCTAssertEqual(s.gameHistory.last?.gameScoreDisplay, "8–6")
    }

    func test_padrao_goldenPoint_recordsGP() {
        var s = newBeach()
        points(.a, 3, &s)
        points(.b, 3, &s)
        XCTAssertTrue(s.isGoldenPoint)
        points(.b, 1, &s)
        XCTAssertEqual(s.setScoreB, 1)
        XCTAssertEqual(s.gameHistory.last?.gameScoreDisplay, GameRecord.goldenPointDisplay)
    }

    func test_legacyPayloadlessBeachRuleset_scoresAsPadrao() {
        let legacy = Ruleset(
            identifier: BeachTennisRuleset.padraoID, name: "Beach Tennis", sport: .beachTennis,
            hasSets: false, gamesToWinMatch: 6, tiebreakAtGames: 6, tiebreakPointsToWin: 7,
            tiebreakWinByTwo: true, setsToWinMatch: nil
        )
        XCTAssertNil(legacy.beachTennis)
        XCTAssertEqual(legacy.beachRules, .padrao)
        var s = MatchState.newMatch(matchType: .beachTennis, initialServer: .a, ruleset: legacy)
        reach(6, 6, &s)
        XCTAssertTrue(s.isTiebreak)
    }

    func test_presetForBeach_isPadrao() {
        XCTAssertEqual(Ruleset.preset(for: .beachTennis).beachTennis, .padrao)
        XCTAssertEqual(Ruleset.preset(for: .beachTennis).identifier, BeachTennisRuleset.padraoID)
    }

    // MARK: - Primeiro a N

    func test_firstTo4_winsAt4_2() {
        var s = newBeach(rules(sets: 4))
        reach(4, 2, &s)
        XCTAssertTrue(s.isMatchOver)
        XCTAssertEqual(s.winner, .a)
    }

    func test_firstTo4_tiebreakAt4_4() {
        var s = newBeach(rules(sets: 4))
        reach(4, 4, &s)
        XCTAssertTrue(s.isTiebreak)
        XCTAssertFalse(s.isMatchOver)
    }

    func test_withoutWinByTwo_6_5_wins() {
        var s = newBeach(rules(winByTwoSets: false))
        reach(5, 5, &s)
        winGame(.b, &s)
        XCTAssertTrue(s.isMatchOver)
        XCTAssertEqual(s.winner, .b)
        XCTAssertFalse(s.isTiebreak)
    }

    func test_firstTo1_withoutWinByTwo_firstGameWins() {
        var s = newBeach(rules(sets: 1, winByTwoSets: false))
        winGame(.b, &s)
        XCTAssertTrue(s.isMatchOver)
        XCTAssertEqual(s.winner, .b)
    }

    func test_tiebreakOff_playsOnUntilTwoSetLead() {
        var s = newBeach(rules(tiebreak: false))
        reach(6, 6, &s)
        XCTAssertFalse(s.isTiebreak)
        XCTAssertFalse(s.isMatchOver)
        games([.a, .b, .b], &s)  // 7–6, 7–7, 7–8
        XCTAssertFalse(s.isMatchOver)
        winGame(.b, &s)          // 7–9
        XCTAssertTrue(s.isMatchOver)
        XCTAssertEqual(s.winner, .b)
    }

    func test_tiebreakTo10() {
        var s = newBeach(rules(tiebreakPoints: 10))
        reach(6, 6, &s)
        points(.a, 8, &s)
        points(.b, 1, &s)
        XCTAssertFalse(s.isMatchOver)   // 8–1: past 7, not yet 10
        points(.a, 2, &s)               // 10–1
        XCTAssertTrue(s.isMatchOver)
        XCTAssertEqual(s.winner, .a)
    }

    func test_tiebreakWithoutWinByTwo_7_6_ends() {
        var s = newBeach(rules(tiebreakWinByTwo: false))
        reach(6, 6, &s)
        points(.a, 6, &s)
        points(.b, 6, &s)
        points(.b, 1, &s)
        XCTAssertTrue(s.isMatchOver)
        XCTAssertEqual(s.winner, .b)
    }

    // MARK: - Sempre N

    func test_always3_twoNil_stillPlaysThird() {
        var s = newBeach(rules(format: .always, sets: 3))
        games([.a, .a], &s)
        XCTAssertFalse(s.isMatchOver)
        winGame(.b, &s)
        XCTAssertTrue(s.isMatchOver)
        XCTAssertEqual(s.winner, .a)
        XCTAssertEqual(s.setScoreA, 2)
        XCTAssertEqual(s.setScoreB, 1)
    }

    func test_always3_sweep_3_0() {
        var s = newBeach(rules(format: .always, sets: 3))
        games([.b, .b, .b], &s)
        XCTAssertTrue(s.isMatchOver)
        XCTAssertEqual(s.winner, .b)
    }

    func test_always4_tied_goesToTiebreak_ends3_2() {
        var s = newBeach(rules(format: .always, sets: 4))
        games([.a, .a, .b, .b], &s)
        XCTAssertTrue(s.isTiebreak)
        XCTAssertFalse(s.isMatchOver)
        points(.b, 7, &s)
        XCTAssertTrue(s.isMatchOver)
        XCTAssertEqual(s.winner, .b)
        XCTAssertEqual(s.setScoreA, 2)
        XCTAssertEqual(s.setScoreB, 3)
    }

    func test_always_ignoresWinByTwo() {
        var s = newBeach(rules(format: .always, sets: 5, winByTwoSets: true))
        games([.a, .a, .a, .b, .b], &s)
        XCTAssertTrue(s.isMatchOver)
        XCTAssertEqual(s.winner, .a)
    }

    // MARK: - Vantagem

    func test_advantage_deuceCycle_recordsAd_neverGoldenPoint() {
        var s = newBeach(rules(deuceRule: .advantage))
        points(.a, 3, &s)
        points(.b, 3, &s)
        XCTAssertFalse(s.isGoldenPoint)
        points(.a, 1, &s)
        XCTAssertEqual(s.advantageTeam, .a)
        XCTAssertEqual(s.setScoreA, 0)
        points(.b, 1, &s)
        XCTAssertNil(s.advantageTeam)
        points(.b, 1, &s)
        XCTAssertEqual(s.advantageTeam, .b)
        points(.b, 1, &s)
        XCTAssertEqual(s.setScoreB, 1)
        XCTAssertNil(s.advantageTeam)
        XCTAssertFalse(s.isGoldenPoint)
        XCTAssertEqual(s.gameHistory.last?.gameScoreDisplay, "Ad")
        XCTAssertEqual(s.pointA, .zero)
        XCTAssertEqual(s.pointB, .zero)
    }

    // MARK: - Validity and codec

    func test_isValid_bounds() {
        XCTAssertTrue(BeachTennisRuleset.padrao.isValid)
        XCTAssertFalse(rules(sets: 0).isValid)
        XCTAssertFalse(rules(sets: 16).isValid)
        XCTAssertFalse(rules(tiebreakPoints: 4).isValid)
        XCTAssertFalse(rules(tiebreakPoints: 22).isValid)
        XCTAssertFalse(rules(format: .always, sets: 4, tiebreak: false).isValid)
        XCTAssertTrue(rules(format: .always, sets: 3, tiebreak: false).isValid)
        XCTAssertTrue(rules(winByTwoSets: false, tiebreak: true).isValid)
    }

    func test_codec_roundTrip() throws {
        let original = Ruleset.beachTennis(rules(format: .always, sets: 5, deuceRule: .advantage))
        let decoded = try JSONDecoder().decode(Ruleset.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.beachTennis?.format, .always)
    }

    func test_codec_legacyBlobWithoutPayload_decodesWithNilPayload() throws {
        let json = """
        {"identifier":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F","name":"Beach Tennis","sport":"beachTennis",
         "hasSets":false,"gamesToWinMatch":6,"tiebreakAtGames":6,"tiebreakPointsToWin":7,"tiebreakWinByTwo":true}
        """
        let decoded = try JSONDecoder().decode(Ruleset.self, from: Data(json.utf8))
        XCTAssertNil(decoded.beachTennis)
        XCTAssertEqual(decoded.beachRules, .padrao)
    }

    func test_codec_beachPayloadOnOtherSport_throws() throws {
        var dict = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(Ruleset.beachTennis(.padrao))
        ) as! [String: Any]
        dict["sport"] = "tennis"
        let data = try JSONSerialization.data(withJSONObject: dict)
        XCTAssertThrowsError(try JSONDecoder().decode(Ruleset.self, from: data))
    }

    func test_codec_invalidKnobs_throw() throws {
        for bad in [rules(sets: 0), rules(tiebreakPoints: 4), rules(format: .always, sets: 4, tiebreak: false)] {
            let data = try JSONEncoder().encode(Ruleset.beachTennis(bad))
            XCTAssertThrowsError(try JSONDecoder().decode(Ruleset.self, from: data))
        }
    }

    func test_newMatch_invalidBeachRuleset_fallsBackToPadrao() {
        let s = newBeach(rules(sets: 0))
        XCTAssertEqual(s.ruleset.beachTennis, .padrao)
    }
}
