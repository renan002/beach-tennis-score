import XCTest
@testable import BeachTennisCounter

/// The ordering the score screen used to own inline, now assertable.
/// Scoring rules themselves belong to `ScoreEngineTests` — nothing here re-tests them.
final class MatchInProgressTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func newMatchInProgress(
        matchType: MatchType = .beachTennis,
        startedAt: Date? = nil
    ) -> MatchInProgress {
        var state = MatchState.newMatch(matchType: matchType, initialServer: .a)
        state.matchStartDate = startedAt ?? start
        return MatchInProgress(state: state)
    }

    // MARK: - Start

    func test_start_savesTheMatchThenStartsTheWorkout() {
        let match = newMatchInProgress()
        XCTAssertEqual(match.start(), [.persist, .startWorkout])
    }

    // MARK: - Awarding a point

    func test_awardPoint_savesThenTapsTheHaptic() {
        var match = newMatchInProgress()
        XCTAssertEqual(match.awardPoint(to: .a, now: start), [.persist, .haptic])
    }

    func test_awardPoint_appliesTheScoringEngineToTheOwnedState() {
        var match = newMatchInProgress()
        _ = match.awardPoint(to: .a, now: start)
        XCTAssertEqual(match.state.point(for: .a), .fifteen)
    }

    func test_awardPoint_pushesThePreviousStateOntoTheUndoStack() {
        var match = newMatchInProgress()
        XCTAssertFalse(match.canUndo)
        _ = match.awardPoint(to: .a, now: start)
        XCTAssertTrue(match.canUndo)
    }

    // MARK: - The point that ends the Match

    func test_matchPoint_sendsTheResultBeforeTearingTheWorkoutDown() {
        var match = matchPointMatch()
        let effects = match.awardPoint(to: .a, now: start.addingTimeInterval(600))

        // The screen snapshots the workout's stats as it performs the send; tear
        // the builder down first and every finished Match loses its calories and
        // heart rate. Payloads are pinned by the two tests below.
        XCTAssertEqual(effects.map(\.name), ["persist", "haptic", "sendResult", "endWorkout"])
    }

    func test_matchPoint_durationIsMeasuredFromTheMatchStartDate() {
        var match = matchPointMatch()
        let effects = match.awardPoint(to: .a, now: start.addingTimeInterval(1_800))

        guard case .sendResult(_, let duration)? = effects.first(where: { $0.isSendResult }) else {
            return XCTFail("expected a result send")
        }
        XCTAssertEqual(duration, 1_800)
    }

    func test_matchPoint_sendsTheFinishedState() {
        var match = matchPointMatch()
        let effects = match.awardPoint(to: .a, now: start)

        guard case .sendResult(let sent, _)? = effects.first(where: { $0.isSendResult }) else {
            return XCTFail("expected a result send")
        }
        XCTAssertTrue(sent.isMatchOver)
        XCTAssertEqual(sent.winner, .a)
    }

    func test_awardPoint_onAFinishedMatch_doesNothing() {
        var match = matchPointMatch()
        _ = match.awardPoint(to: .a, now: start)
        XCTAssertEqual(match.awardPoint(to: .b, now: start), [])
    }

    // MARK: - Undo

    func test_undo_savesThenTapsTheHaptic() {
        var match = newMatchInProgress()
        _ = match.awardPoint(to: .a, now: start)
        XCTAssertEqual(match.undo(), [.persist, .haptic])
    }

    func test_undo_restoresThePreviousState() {
        var match = newMatchInProgress()
        _ = match.awardPoint(to: .a, now: start)
        _ = match.undo()
        XCTAssertEqual(match.state.point(for: .a), .zero)
        XCTAssertFalse(match.canUndo)
    }

    func test_undo_withNothingToUndo_producesNoEffects() {
        var match = newMatchInProgress()
        XCTAssertEqual(match.undo(), [])
    }

    func test_undo_onAMatchRestoredFromASavedMatch_producesNoEffects() {
        // Pins the resume decision: a resumed Match starts with an empty Undo
        // Stack, so the point played before the app died cannot be taken back.
        var saved = MatchState.newMatch(matchType: .beachTennis, initialServer: .a)
        ScoreEngine.awardPoint(to: .a, state: &saved)
        var match = MatchInProgress(state: saved)

        XCTAssertEqual(match.undo(), [])
        XCTAssertEqual(match.state.point(for: .a), .fifteen)
    }

    func test_undo_afterTheMatchEnded_producesNoEffects() {
        // The Undo Stack is discarded when the Match ends.
        var match = matchPointMatch()
        _ = match.awardPoint(to: .a, now: start)
        XCTAssertEqual(match.undo(), [])
    }

    // MARK: - Cancel

    func test_cancel_cancelsTheWorkoutAndClearsTheSavedMatch() {
        let match = newMatchInProgress()
        XCTAssertEqual(
            match.cancel(now: start.addingTimeInterval(90)),
            [.cancelWorkout(elapsed: 90), .clearPersisted]
        )
    }

    func test_cancel_elapsedIsMeasuredFromTheMatchStartDate() {
        // The discard-versus-save verdict stays in `WorkoutPolicy`; the module
        // only carries the elapsed time it is decided from.
        let match = newMatchInProgress()
        guard case .cancelWorkout(let elapsed) = match.cancel(now: start.addingTimeInterval(300))[0] else {
            return XCTFail("expected a workout cancel")
        }
        XCTAssertEqual(elapsed, 300)
        XCTAssertEqual(WorkoutPolicy.cancelDecision(elapsed: elapsed), .save)
    }

    // MARK: - Helpers

    /// A Match one point from over: 5 games to 0, 40–0 in the sixth.
    private func matchPointMatch() -> MatchInProgress {
        var state = MatchState.newMatch(matchType: .beachTennis, initialServer: .a)
        state.matchStartDate = start
        var match = MatchInProgress(state: state)
        while match.state.setScoreA < 5 {
            _ = match.awardPoint(to: .a, now: start)
        }
        while match.state.point(for: .a) != .forty {
            _ = match.awardPoint(to: .a, now: start)
        }
        return match
    }
}

private extension MatchInProgress.Effect {
    /// The case alone, so an ordering assertion doesn't have to restate payloads
    /// — least of all by reading them back off the module under test.
    var name: String {
        switch self {
        case .persist:        return "persist"
        case .clearPersisted: return "clearPersisted"
        case .haptic:         return "haptic"
        case .startWorkout:   return "startWorkout"
        case .sendResult:     return "sendResult"
        case .endWorkout:     return "endWorkout"
        case .cancelWorkout:  return "cancelWorkout"
        }
    }

    var isSendResult: Bool { name == "sendResult" }
}
