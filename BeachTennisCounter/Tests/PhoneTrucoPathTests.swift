import XCTest
import SwiftData
@testable import BeachTennisCounter

/// The plumbing under the phone's own truco Placar: hand corrections, and the
/// single payload → Match History path shared with the watch.
final class PhoneTrucoPathTests: XCTestCase {

    private func truco() -> MatchInProgress {
        MatchInProgress(state: MatchState.newMatch(matchType: .truco, initialServer: .a, ruleset: .truco(.paulista)))
    }

    private func finishedTruco() -> MatchState {
        var m = truco()
        _ = m.awardPoint(to: .a, value: 6)
        _ = m.awardPoint(to: .a, value: 6)
        return m.state
    }

    // MARK: - Engine

    func test_removeTrucoHand_rederivesTotals() {
        var s = truco().state
        ScoreEngine.awardPoint(to: .a, value: 6, state: &s)
        ScoreEngine.awardPoint(to: .b, value: 3, state: &s)
        XCTAssertTrue(ScoreEngine.removeTrucoHand(at: 0, state: &s))
        XCTAssertEqual(s.setScoreA, 0)
        XCTAssertEqual(s.setScoreB, 3)
        XCTAssertEqual(s.gameHistory.map(\.gameNumber), [1])
    }

    func test_removeTrucoHand_reopensAFinishedMatch() {
        var s = finishedTruco()
        XCTAssertTrue(s.isMatchOver)
        XCTAssertTrue(ScoreEngine.removeTrucoHand(at: 1, state: &s))
        XCTAssertFalse(s.isMatchOver)
        XCTAssertNil(s.winner)
    }

    func test_removeTrucoHand_refusesBadIndexAndOtherSports() {
        var s = truco().state
        XCTAssertFalse(ScoreEngine.removeTrucoHand(at: 0, state: &s))
        var beach = MatchState.newMatch(matchType: .beachTennis, initialServer: .a)
        XCTAssertFalse(ScoreEngine.removeTrucoHand(at: 0, state: &beach))
    }

    // MARK: - MatchInProgress

    func test_correctHand_midMatch_persistsWithHaptic() {
        var m = truco()
        _ = m.awardPoint(to: .a, value: 3)
        XCTAssertEqual(m.correctHand(at: 0, value: 9), [.persist, .haptic])
        XCTAssertEqual(m.state.setScoreA, 9)
    }

    func test_correctHand_landingOnTheTargetAtTheLastHand_sendsTheResultBeforeEndingTheWorkout() {
        var m = truco()
        _ = m.awardPoint(to: .a, value: 6)
        _ = m.awardPoint(to: .a, value: 3)
        let effects = m.correctHand(at: 1, value: 6)
        XCTAssertEqual(effects.count, 4)
        XCTAssertEqual(Array(effects.prefix(2)), [.persist, .haptic])
        guard case .sendResult(let state, _) = effects[2] else { return XCTFail("expected sendResult") }
        XCTAssertEqual(state.winner, .a)
        XCTAssertEqual(effects[3], .endWorkout)
        XCTAssertFalse(m.canUndo)
    }

    func test_correctHand_thatWouldEndTheMatchEarly_isRefused() {
        var m = truco()
        _ = m.awardPoint(to: .a, value: 6)
        _ = m.awardPoint(to: .a, value: 3)
        let before = m.state
        XCTAssertEqual(m.correctHand(at: 0, value: 12), [])
        XCTAssertEqual(m.state, before)
    }

    func test_correctHand_isUndoable() {
        var m = truco()
        _ = m.awardPoint(to: .a, value: 3)
        _ = m.correctHand(at: 0, value: 9)
        XCTAssertEqual(m.undo(), [.persist, .haptic])
        XCTAssertEqual(m.state.setScoreA, 3)
    }

    func test_removeHand_dropsItAndIsUndoable() {
        var m = truco()
        _ = m.awardPoint(to: .a, value: 3)
        _ = m.awardPoint(to: .b, value: 1)
        XCTAssertEqual(m.removeHand(at: 0), [.persist, .haptic])
        XCTAssertEqual(m.state.setScoreA, 0)
        _ = m.undo()
        XCTAssertEqual(m.state.setScoreA, 3)
        XCTAssertEqual(m.removeHand(at: 9), [], "out of range is refused")
    }

    func test_correctionsAreIgnoredOnceTheMatchIsOver() {
        var m = MatchInProgress(state: finishedTruco())
        XCTAssertEqual(m.correctHand(at: 0, value: 3), [])
        XCTAssertEqual(m.removeHand(at: 0), [])
    }

    // MARK: - Payload

    func test_payload_isNilWithoutAWinner() {
        XCTAssertNil(MatchResultPayload(finished: truco().state, duration: 10))
    }

    func test_payload_carriesTrucoTotalsRulesetAndHands() throws {
        let state = finishedTruco()
        let p = try XCTUnwrap(MatchResultPayload(finished: state, duration: 42))
        XCTAssertEqual(p.matchType, .truco)
        XCTAssertEqual(p.winner, .a)
        XCTAssertEqual(p.setScoreA, 12)
        XCTAssertEqual(p.setScoreB, 0)
        XCTAssertEqual(p.gameHistory, state.gameHistory)
        XCTAssertEqual(try JSONDecoder().decode(Ruleset.self, from: p.rulesetData).truco, .paulista)
        XCTAssertNil(p.pingPointsA)
    }

    func test_payload_pingPong_mapsGamesWonAndKeepsPoints() throws {
        var s = MatchState.newMatch(matchType: .pingPong, initialServer: .a)
        while !s.isMatchOver { ScoreEngine.awardPoint(to: .a, state: &s) }
        let p = try XCTUnwrap(MatchResultPayload(finished: s, duration: 1))
        XCTAssertEqual(p.setScoreA, s.pingGamesWon(for: .a))
        XCTAssertEqual(p.pingPointsA, s.pingPoints(for: .a))
        XCTAssertEqual(p.pingPointsB, s.pingPoints(for: .b))
    }

    // MARK: - Insert

    @MainActor
    private func memoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: StoredMatch.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @MainActor
    func test_insert_phoneAndWatchPathsProduceTheSameRow() throws {
        let payload = try XCTUnwrap(MatchResultPayload(finished: finishedTruco(), duration: 42))
        let wire = try XCTUnwrap(MatchResultPayload.from(payload.toDictionary()))

        let phoneRows = try memoryContext()
        let watchRows = try memoryContext()
        StoredMatch.insert(payload, into: phoneRows)
        StoredMatch.insert(wire, into: watchRows)

        let a = try XCTUnwrap(phoneRows.fetch(FetchDescriptor<StoredMatch>()).first)
        let b = try XCTUnwrap(watchRows.fetch(FetchDescriptor<StoredMatch>()).first)
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(a.matchTypeRaw, "truco")
        XCTAssertEqual(a.setScoreA, b.setScoreA)
        XCTAssertEqual(a.setScoreB, b.setScoreB)
        XCTAssertEqual(a.winner, b.winner)
        // Decoded, not byte-compared: JSONEncoder does not fix key order.
        XCTAssertEqual(a.gameHistory, b.gameHistory)
        XCTAssertFalse(a.gameHistory.isEmpty)
        XCTAssertEqual(
            try JSONDecoder().decode(Ruleset.self, from: a.rulesetData),
            try JSONDecoder().decode(Ruleset.self, from: b.rulesetData)
        )
        XCTAssertEqual(a.teamAName, b.teamAName)
    }

    @MainActor
    func test_insert_sameMatchIdTwice_leavesOneRow() throws {
        let payload = try XCTUnwrap(MatchResultPayload(finished: finishedTruco(), duration: 42))
        let context = try memoryContext()
        StoredMatch.insert(payload, into: context)
        StoredMatch.insert(payload, into: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoredMatch>()), 1)
    }
}
