import Foundation

/// The Match currently being scored: its state, its Undo Stack, and the effects
/// each interaction produces.
///
/// A pure value with no dependencies — it never reaches for the in-progress
/// store, the workout or the phone session. Every interaction returns the
/// ordered list of effects the score screen must carry out, which is what makes
/// the ordering assertable: the watch target is reachable by no test in this
/// project, so an ordering written inline there is an ordering nobody can pin.
///
/// The load-bearing order is the terminal one — the result send comes *before*
/// the workout teardown, because the send carries the workout's stats snapshot
/// and a torn-down builder has none to give.
struct MatchInProgress {

    /// Something the screen must do. Effects that need no payload read the
    /// module's `state` at the moment they are performed.
    enum Effect: Equatable {
        /// Save the Match in progress so a mid-Match termination costs no points.
        case persist
        /// Drop the saved Match — nothing is left to resume.
        case clearPersisted
        /// The tap feedback for an accepted interaction.
        case haptic
        case startWorkout
        /// Send the finished Match to the phone. Carries the state and duration
        /// by value: this is the terminal snapshot, not whatever the module
        /// holds later.
        case sendResult(state: MatchState, duration: TimeInterval)
        /// End and save the workout for a finished Match.
        case endWorkout
        /// Cancel the workout for an abandoned Match. Carries the elapsed play
        /// time only — the discard-versus-save verdict stays in `WorkoutPolicy`.
        case cancelWorkout(elapsed: TimeInterval)
    }

    /// The Match being scored.
    private(set) var state: MatchState

    /// The Undo Stack: earlier states, kept only so a player can take back a
    /// point entered by mistake. Empty on a resumed Match and discarded when
    /// the Match ends.
    private var undoStack: [MatchState] = []

    /// Whether there is a point to take back — what the undo control's enabled
    /// state reads.
    var canUndo: Bool { !undoStack.isEmpty }

    /// Starts scoring `state`, fresh or restored. A restored Match brings no
    /// Undo Stack: the points played before the app died are not takeable back.
    init(state: MatchState) {
        self.state = state
    }

    /// The screen appeared: save what will be scored, then start the workout.
    func start() -> [Effect] {
        [.persist, .startWorkout]
    }

    /// A point went to `team`.
    mutating func awardPoint(to team: Team, now: Date = Date()) -> [Effect] {
        guard !state.isMatchOver else { return [] }

        undoStack.append(state)
        ScoreEngine.awardPoint(to: team, state: &state)

        var effects: [Effect] = [.persist, .haptic]
        guard state.isMatchOver else { return effects }

        undoStack.removeAll()
        effects.append(.sendResult(
            state: state,
            duration: now.timeIntervalSince(state.matchStartDate)
        ))
        effects.append(.endWorkout)
        return effects
    }

    /// Takes back the last point. No effects when there is nothing to take back.
    mutating func undo() -> [Effect] {
        guard let previous = undoStack.popLast() else { return [] }
        state = previous
        return [.persist, .haptic]
    }

    /// The player abandoned the Match.
    func cancel(now: Date = Date()) -> [Effect] {
        [
            .cancelWorkout(elapsed: now.timeIntervalSince(state.matchStartDate)),
            .clearPersisted
        ]
    }
}
