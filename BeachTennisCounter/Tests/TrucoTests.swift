import XCTest
@testable import BeachTennisCounter

final class TrucoTests: XCTestCase {

    private func newMatch(_ rules: TrucoRuleset = .paulista) -> MatchState {
        MatchState.newMatch(matchType: .truco, initialServer: .a, ruleset: .truco(rules))
    }

    // MARK: - Ruleset

    func test_presets_areTheResearchedLadders() {
        XCTAssertEqual(TrucoRuleset.paulista.stakes, [1, 3, 6, 9, 12])
        XCTAssertEqual(TrucoRuleset.paulista.pointsTarget, 12)
        XCTAssertEqual(TrucoRuleset.mineiro.stakes, [2, 4, 6, 10, 12])
        XCTAssertEqual(TrucoRuleset.gauderio.stakes, [1, 2, 3, 4])
        XCTAssertEqual(TrucoRuleset.gauderio.pointsTarget, 24)
        XCTAssertTrue(TrucoRuleset.presets.allSatisfy(\.isValid))
        XCTAssertEqual(Ruleset.preset(for: .truco).truco, .paulista)
    }

    func test_ladderValidation() {
        XCTAssertTrue(TrucoRuleset.isValidLadder([3], base: 1))
        XCTAssertTrue(TrucoRuleset.isValidLadder([2, 3, 4, 5], base: 1))
        XCTAssertFalse(TrucoRuleset.isValidLadder([], base: 1), "at least one raise")
        XCTAssertFalse(TrucoRuleset.isValidLadder([2, 3, 4, 5, 6], base: 1), "at most four raises")
        XCTAssertFalse(TrucoRuleset.isValidLadder([3, 2], base: 1), "strictly increasing")
        XCTAssertFalse(TrucoRuleset.isValidLadder([3, 3], base: 1), "strictly increasing")
        XCTAssertFalse(TrucoRuleset.isValidLadder([2, 3], base: 2), "first raise above the base")
        XCTAssertFalse(TrucoRuleset.paulista.with(baseValue: 3).isValid, "base is 1 or 2")
        XCTAssertFalse(TrucoRuleset.paulista.with(pointsTarget: 0).isValid)
    }

    func test_ruleset_roundTripsAndRejectsMissingPayload() throws {
        let data = try JSONEncoder().encode(Ruleset.truco(.mineiro))
        XCTAssertEqual(try JSONDecoder().decode(Ruleset.self, from: data).truco, .mineiro)

        var dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        dict.removeValue(forKey: "payloadType")
        dict.removeValue(forKey: "truco")
        let stripped = try JSONSerialization.data(withJSONObject: dict)
        XCTAssertThrowsError(try JSONDecoder().decode(Ruleset.self, from: stripped))
    }

    // MARK: - Engine

    func test_tapCreditsBaseValue() {
        var s = newMatch(.mineiro)
        ScoreEngine.awardPoint(to: .a, state: &s)
        XCTAssertEqual(s.setScoreA, 2)
        XCTAssertEqual(s.gameHistory.count, 1)
        XCTAssertEqual(s.gameHistory[0].gameScoreDisplay, "+2")
        XCTAssertEqual(MatchState.trucoHandValue(s.gameHistory[0]), 2)
    }

    func test_valueNotOnTheLadderIsRefused() {
        var s = newMatch()
        ScoreEngine.awardPoint(to: .a, value: 4, state: &s)
        XCTAssertEqual(s, newMatch().withStartDate(s.matchStartDate))
    }

    func test_reachingTargetEndsMatch_uncapped() {
        var s = newMatch()
        ScoreEngine.awardPoint(to: .b, value: 9, state: &s)
        ScoreEngine.awardPoint(to: .a, value: 1, state: &s)
        XCTAssertFalse(s.isMatchOver)
        ScoreEngine.awardPoint(to: .b, value: 6, state: &s)
        XCTAssertTrue(s.isMatchOver)
        XCTAssertEqual(s.winner, .b)
        XCTAssertEqual(HeadlineScore.live(s), HeadlineScore(a: 1, b: 15, unit: .points))
        ScoreEngine.awardPoint(to: .a, value: 12, state: &s)
        XCTAssertEqual(s.gameHistory.count, 3, "no hand after the end")
    }

    func test_correctingAHandDownReopensTheMatch() {
        var s = newMatch()
        ScoreEngine.awardPoint(to: .a, value: 9, state: &s)
        ScoreEngine.awardPoint(to: .a, value: 3, state: &s)
        XCTAssertTrue(s.isMatchOver)

        XCTAssertTrue(ScoreEngine.correctTrucoHand(at: 1, winner: .a, value: 1, state: &s))
        XCTAssertFalse(s.isMatchOver)
        XCTAssertNil(s.winner)
        XCTAssertEqual(s.setScoreA, 10)
        XCTAssertEqual(s.gameHistory.map(\.setScoreA), [9, 10])
    }

    func test_correctionThatWouldEndBeforeTheLastHandIsRefused() {
        var s = newMatch()
        ScoreEngine.awardPoint(to: .a, value: 9, state: &s)
        ScoreEngine.awardPoint(to: .b, value: 1, state: &s)
        let before = s
        XCTAssertFalse(ScoreEngine.correctTrucoHand(at: 0, winner: .a, value: 12, state: &s))
        XCTAssertEqual(s, before)
    }

    // MARK: - Match In Progress

    func test_refusedValueLeavesNoUndoEntryOrEffects() {
        var match = MatchInProgress(state: newMatch())
        XCTAssertEqual(match.awardPoint(to: .a, value: 5), [])
        XCTAssertFalse(match.canUndo)
        XCTAssertFalse(match.awardPoint(to: .a, value: 3).isEmpty)
        XCTAssertTrue(match.canUndo)
    }

    func test_isNotPhysical_andHasNoServe() {
        XCTAssertFalse(MatchType.truco.isPhysicalSport)
        XCTAssertFalse(MatchType.truco.hasServe)
        XCTAssertEqual(
            WorkoutPolicy.startDecision(
                monitoringEnabled: true, sessionRunning: false,
                recoveryPending: false, sportIsPhysical: MatchType.truco.isPhysicalSport
            ),
            .skip
        )
    }

    // MARK: - Persistence and wire

    func test_persistedMatch_rederivesTotalsFromHands() throws {
        var s = newMatch()
        ScoreEngine.awardPoint(to: .a, value: 3, state: &s)
        ScoreEngine.awardPoint(to: .b, state: &s)
        var tampered = s
        tampered.setScoreA = 99
        tampered.isMatchOver = true
        let decoded = try JSONDecoder().decode(MatchState.self, from: JSONEncoder().encode(tampered))
        XCTAssertEqual(decoded.setScoreA, 3)
        XCTAssertEqual(decoded.setScoreB, 1)
        XCTAssertFalse(decoded.isMatchOver)
    }

    func test_persistedMatch_withHandCreditingBothSidesIsMalformed() throws {
        var s = newMatch()
        s.gameHistory = [GameRecord(gameNumber: 1, setScoreA: 3, setScoreB: 1, winner: .a,
                                    isTiebreak: false, pointsA: 3, pointsB: 1)]
        XCTAssertThrowsError(try JSONDecoder().decode(MatchState.self, from: JSONEncoder().encode(s)))
    }

    func test_payloadRequiresStampedTrucoRuleset() throws {
        let payload = MatchResultPayload(
            matchId: UUID(), setScoreA: 12, setScoreB: 4, setsWonA: 0, setsWonB: 0,
            winner: .a, duration: 60, date: Date(), gameHistory: [], setHistory: [],
            matchType: .truco, teamAName: "", teamBName: "",
            rulesetData: try JSONEncoder().encode(Ruleset.truco(.paulista))
        )
        XCTAssertEqual(MatchResultPayload.from(payload.toDictionary())?.matchType, .truco)

        var dict = payload.toDictionary()
        dict[WatchMessageKey.rulesetData] = Data()
        XCTAssertNil(MatchResultPayload.from(dict))
    }
}

private extension MatchState {
    func withStartDate(_ date: Date) -> MatchState {
        var copy = self
        copy.matchStartDate = date
        return copy
    }
}
