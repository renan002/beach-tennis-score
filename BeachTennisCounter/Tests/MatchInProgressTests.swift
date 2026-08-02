import XCTest
@testable import BeachTennisCounter

/// The watch's scoring flow, at the highest seam this project has: the four
/// interactions and the effects they return. Everything asserted here used to be
/// statements inside `ScoreView`, on the watch target, which no test can reach.
///
/// This sits *above* `ScoreEngine` and re-tests none of its rules — the scoring
/// suites stay where they are. What is settled here is what the screen does
/// around a point: what is saved, what clicks, what is sent, and in what order.
final class MatchInProgressTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func newMatch(_ matchType: MatchType = .beachTennis) -> MatchInProgress {
        MatchInProgress.new(matchType: matchType, initialServer: .a)
    }

    /// Plays `team` until the Match is over, returning the effects of the point
    /// that ended it. Beach tennis is first to 6 games; won at love that is 24
    /// points, and the guard keeps a rules change from turning this into a hang.
    private func playToMatchOver(
        _ match: inout MatchInProgress,
        winner team: Team,
        now: Date
    ) -> [MatchEffect] {
        for _ in 0..<200 {
            let effects = match.awardPoint(to: team, now: now)
            if match.state.isMatchOver { return effects }
        }
        XCTFail("match never ended")
        return []
    }

    // MARK: - Start

    /// Saved from the first frame, so a Match survives a kill before its first
    /// point — and the workout begins only after the Match exists on disk.
    func test_start_persistsThenStartsWorkout() {
        let match = newMatch()
        XCTAssertEqual(match.start(), [.persist, .startWorkout])
    }

    func test_start_leavesTheMatchUntouched() {
        let match = newMatch()
        let before = match.state
        _ = match.start()
        XCTAssertEqual(match.state, before)
        XCTAssertFalse(match.canUndo)
    }

    // MARK: - A point

    func test_awardPoint_persistsAndClicks() {
        var match = newMatch()
        XCTAssertEqual(match.awardPoint(to: .a, now: start), [.persist, .haptic])
    }

    func test_awardPoint_scoresThroughTheEngine() {
        var match = newMatch()
        _ = match.awardPoint(to: .a, now: start)
        XCTAssertEqual(match.state.pointA, .fifteen)
        XCTAssertEqual(match.state.pointB, .zero)
    }

    func test_awardPoint_pushesTheUndoStack() {
        var match = newMatch()
        XCTAssertFalse(match.canUndo)
        _ = match.awardPoint(to: .a, now: start)
        XCTAssertTrue(match.canUndo)
    }

    // MARK: - The point that ends the Match

    /// The load-bearing assertion of this module: the result is sent **before**
    /// the workout is torn down. The screen snapshots the workout stats while
    /// performing the send, and the builder they come from is gone once
    /// `endWorkout` has run — reversed, every finished Match silently loses its
    /// calories and average heart rate.
    func test_matchEndingPoint_sendsResultBeforeEndingTheWorkout() {
        var match = newMatch()
        let effects = playToMatchOver(&match, winner: .a, now: start)

        guard effects.count == 4 else {
            return XCTFail("expected persist, haptic, send, end — got \(effects)")
        }
        XCTAssertEqual(effects[0], .persist)
        XCTAssertEqual(effects[1], .haptic)
        XCTAssertEqual(
            effects[2],
            .sendResult(state: match.state, duration: start.timeIntervalSince(match.state.matchStartDate))
        )
        XCTAssertEqual(effects[3], .endWorkout)
    }

    /// The sent state is the finished Match, winner and all — the payload the
    /// phone stores comes from the effect, not from a later read of the screen.
    func test_matchEndingPoint_sendsTheFinishedMatch() {
        var match = newMatch()
        let effects = playToMatchOver(&match, winner: .a, now: start)

        guard case .sendResult(let sent, _)? = effects.first(where: {
            if case .sendResult = $0 { return true } else { return false }
        }) else {
            return XCTFail("no send in \(effects)")
        }
        XCTAssertTrue(sent.isMatchOver)
        XCTAssertEqual(sent.winner, .a)
        XCTAssertEqual(sent.setScoreA, 6)
    }

    /// The duration is computed from the Match start against the injected `now`,
    /// the same convention the in-progress store uses.
    func test_matchEndingPoint_durationRunsFromMatchStart() {
        var match = newMatch()
        let end = match.state.matchStartDate.addingTimeInterval(1_800)
        let effects = playToMatchOver(&match, winner: .b, now: end)

        guard case .sendResult(_, let duration)? = effects.first(where: {
            if case .sendResult = $0 { return true } else { return false }
        }) else {
            return XCTFail("no send in \(effects)")
        }
        XCTAssertEqual(duration, 1_800, accuracy: 0.001)
    }

    /// Every point before the last returns the two ordinary effects and nothing
    /// else — no send, no workout teardown mid-Match.
    func test_pointsBeforeTheLast_sendNothing() {
        var match = newMatch()
        for _ in 0..<3 {
            let effects = match.awardPoint(to: .a, now: start)
            XCTAssertEqual(effects, [.persist, .haptic])
            XCTAssertFalse(match.state.isMatchOver)
        }
    }

    // MARK: - Undo

    func test_undo_restoresThePreviousStateAndSaves() {
        var match = newMatch()
        let before = match.state
        _ = match.awardPoint(to: .a, now: start)

        XCTAssertEqual(match.undo(), [.persist, .haptic])
        XCTAssertEqual(match.state, before)
        XCTAssertFalse(match.canUndo)
    }

    /// Nothing to undo returns no effects at all — nothing saved, no click. The
    /// arrow is disabled in this state, and the module agrees with it.
    func test_undo_onAFreshMatch_returnsNothing() {
        var match = newMatch()
        XCTAssertFalse(match.canUndo)
        XCTAssertEqual(match.undo(), [])
    }

    /// **A resumed Match has no Undo Stack.** The in-progress store persists the
    /// Match state alone, so a restored Match cannot restore earlier states —
    /// the first point after a resume is not undoable. Pinned here so it stays a
    /// decision rather than drifting back into an accident.
    func test_undo_onARestoredMatch_returnsNothing() {
        var restored = MatchInProgress.restored(
            .newMatch(matchType: .beachTennis, initialServer: .a)
        )
        XCTAssertFalse(restored.canUndo)
        XCTAssertEqual(restored.undo(), [])
    }

    /// A point entered *after* the resume is undoable as usual — the stack is
    /// empty at the resume, not disabled for the rest of the Match.
    func test_undo_afterAPointOnARestoredMatch_works() {
        var restored = MatchInProgress.restored(
            .newMatch(matchType: .beachTennis, initialServer: .a)
        )
        _ = restored.awardPoint(to: .b, now: start)
        XCTAssertTrue(restored.canUndo)
        XCTAssertEqual(restored.undo(), [.persist, .haptic])
        XCTAssertFalse(restored.canUndo)
    }

    func test_undo_unwindsPointByPoint() {
        var match = newMatch()
        _ = match.awardPoint(to: .a, now: start)
        let afterOne = match.state
        _ = match.awardPoint(to: .a, now: start)

        _ = match.undo()
        XCTAssertEqual(match.state, afterOne)
        XCTAssertTrue(match.canUndo)
        _ = match.undo()
        XCTAssertFalse(match.canUndo)
    }

    // MARK: - Cancel

    /// Cancelling leaves nothing behind: the saved Match is cleared, so the next
    /// launch never offers to resume a Match the player walked away from.
    func test_cancel_cancelsTheWorkoutThenClearsTheSavedMatch() {
        var match = newMatch()
        _ = match.awardPoint(to: .a, now: start)
        let cancelledAt = match.state.matchStartDate.addingTimeInterval(30)

        XCTAssertEqual(
            match.cancel(now: cancelledAt),
            [.cancelWorkout(elapsed: 30), .clearPersisted]
        )
    }

    /// The elapsed time is the Match's, from its start — the number the workout
    /// adapter feeds to `WorkoutPolicy.cancelDecision`. The discard-versus-save
    /// policy itself is not re-decided here; it has its own module and tests.
    func test_cancel_elapsedRunsFromMatchStart() {
        let match = newMatch()
        let longMatch = match.state.matchStartDate.addingTimeInterval(3_600)
        XCTAssertEqual(
            match.cancel(now: longMatch),
            [.cancelWorkout(elapsed: 3_600), .clearPersisted]
        )
    }

    // MARK: - The Match it holds

    func test_new_stampsTheMatchAsScoreViewUsedTo() {
        let match = MatchInProgress.new(
            matchType: .tennis,
            initialServer: .b,
            teamAName: "Renan",
            teamBName: "Bruno"
        )
        XCTAssertEqual(match.state.matchType, .tennis)
        XCTAssertEqual(match.state.initialServer, .b)
        XCTAssertEqual(match.state.teamAName, "Renan")
        XCTAssertEqual(match.state.teamBName, "Bruno")
    }

    /// A resumed Match keeps everything it was restored with — its own stamped
    /// names, its serve wiring and its start date, which is what the duration
    /// and the cancel elapsed time are measured from.
    func test_restored_keepsTheRestoredMatchWhole() {
        var saved = MatchState.newMatch(
            matchType: .tennis,
            initialServer: .b,
            teamAName: "Renan",
            teamBName: "Bruno"
        )
        saved.setScoreA = 3
        saved.matchStartDate = start

        let match = MatchInProgress.restored(saved)
        XCTAssertEqual(match.state, saved)
    }
}
