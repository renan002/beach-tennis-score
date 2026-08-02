import XCTest
@testable import BeachTennisCounter

/// The ordering the score screen used to own inline, now assertable.
/// Scoring rules themselves belong to `ScoreEngineTests` — nothing here re-tests them.
final class MatchInProgressTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func newSession(
        matchType: MatchType = .beachTennis,
        startedAt: Date? = nil
    ) -> MatchInProgress {
        var state = MatchState.newMatch(matchType: matchType, initialServer: .a)
        state.matchStartDate = startedAt ?? start
        return MatchInProgress(state: state)
    }

    // MARK: - Start

    func test_start_savesTheMatchThenStartsTheWorkout() {
        let session = newSession()
        XCTAssertEqual(session.start(), [.persist, .startWorkout])
    }

    // MARK: - Awarding a point

    func test_awardPoint_savesThenTapsTheHaptic() {
        var session = newSession()
        XCTAssertEqual(session.awardPoint(to: .a, now: start), [.persist, .haptic])
    }

    func test_awardPoint_appliesTheScoringEngineToTheOwnedState() {
        var session = newSession()
        _ = session.awardPoint(to: .a, now: start)
        XCTAssertEqual(session.state.point(for: .a), .fifteen)
    }

    func test_awardPoint_pushesThePreviousStateOntoTheUndoStack() {
        var session = newSession()
        XCTAssertFalse(session.canUndo)
        _ = session.awardPoint(to: .a, now: start)
        XCTAssertTrue(session.canUndo)
    }

    // MARK: - The point that ends the Match

    func test_matchPoint_sendsTheResultBeforeTearingTheWorkoutDown() {
        var session = matchPointSession()
        let effects = session.awardPoint(to: .a, now: start.addingTimeInterval(600))

        // The stats snapshot rides on the send; tear the builder down first and
        // every finished Match loses its calories and heart rate.
        XCTAssertEqual(effects, [
            .persist,
            .haptic,
            .sendResult(state: session.state, duration: 600),
            .endWorkout
        ])
    }

    func test_matchPoint_durationIsMeasuredFromTheMatchStartDate() {
        var session = matchPointSession()
        let effects = session.awardPoint(to: .a, now: start.addingTimeInterval(1_800))

        guard case .sendResult(_, let duration)? = effects.first(where: { $0.isSendResult }) else {
            return XCTFail("expected a result send")
        }
        XCTAssertEqual(duration, 1_800)
    }

    func test_matchPoint_sendsTheFinishedState() {
        var session = matchPointSession()
        let effects = session.awardPoint(to: .a, now: start)

        guard case .sendResult(let sent, _)? = effects.first(where: { $0.isSendResult }) else {
            return XCTFail("expected a result send")
        }
        XCTAssertTrue(sent.isMatchOver)
        XCTAssertEqual(sent.winner, .a)
    }

    func test_awardPoint_onAFinishedMatch_doesNothing() {
        var session = matchPointSession()
        _ = session.awardPoint(to: .a, now: start)
        XCTAssertEqual(session.awardPoint(to: .b, now: start), [])
    }

    // MARK: - Undo

    func test_undo_savesThenTapsTheHaptic() {
        var session = newSession()
        _ = session.awardPoint(to: .a, now: start)
        XCTAssertEqual(session.undo(), [.persist, .haptic])
    }

    func test_undo_restoresThePreviousState() {
        var session = newSession()
        _ = session.awardPoint(to: .a, now: start)
        _ = session.undo()
        XCTAssertEqual(session.state.point(for: .a), .zero)
        XCTAssertFalse(session.canUndo)
    }

    func test_undo_withNothingToUndo_producesNoEffects() {
        var session = newSession()
        XCTAssertEqual(session.undo(), [])
    }

    func test_undo_onASessionRestoredFromASavedMatch_producesNoEffects() {
        // Pins the resume decision: a resumed Match starts with an empty Undo
        // Stack, so the point played before the app died cannot be taken back.
        var saved = MatchState.newMatch(matchType: .beachTennis, initialServer: .a)
        ScoreEngine.awardPoint(to: .a, state: &saved)
        var session = MatchInProgress(state: saved)

        XCTAssertEqual(session.undo(), [])
        XCTAssertEqual(session.state.point(for: .a), .fifteen)
    }

    func test_undo_afterTheMatchEnded_producesNoEffects() {
        // The Undo Stack is discarded when the Match ends.
        var session = matchPointSession()
        _ = session.awardPoint(to: .a, now: start)
        XCTAssertEqual(session.undo(), [])
    }

    // MARK: - Cancel

    func test_cancel_cancelsTheWorkoutAndClearsTheSavedMatch() {
        let session = newSession()
        XCTAssertEqual(
            session.cancel(now: start.addingTimeInterval(90)),
            [.cancelWorkout(elapsed: 90), .clearPersisted]
        )
    }

    func test_cancel_elapsedIsMeasuredFromTheMatchStartDate() {
        // The discard-versus-save verdict stays in `WorkoutPolicy`; the module
        // only carries the elapsed time it is decided from.
        let session = newSession()
        guard case .cancelWorkout(let elapsed) = session.cancel(now: start.addingTimeInterval(300))[0] else {
            return XCTFail("expected a workout cancel")
        }
        XCTAssertEqual(elapsed, 300)
        XCTAssertEqual(WorkoutPolicy.cancelDecision(elapsed: elapsed), .save)
    }

    // MARK: - Helpers

    /// A Match one point from over: 5 games to 0, 40–0 in the sixth.
    private func matchPointSession() -> MatchInProgress {
        var state = MatchState.newMatch(matchType: .beachTennis, initialServer: .a)
        state.matchStartDate = start
        var session = MatchInProgress(state: state)
        while session.state.setScoreA < 5 {
            _ = session.awardPoint(to: .a, now: start)
        }
        while session.state.point(for: .a) != .forty {
            _ = session.awardPoint(to: .a, now: start)
        }
        return session
    }
}

private extension MatchInProgress.Effect {
    var isSendResult: Bool {
        if case .sendResult = self { return true }
        return false
    }
}
