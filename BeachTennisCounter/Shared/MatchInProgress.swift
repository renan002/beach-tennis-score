import Foundation

/// Something the score screen must do as a result of an interaction with the
/// Match In Progress. A value, not a call: the module names what has to happen
/// and in what order, the screen carries it out.
///
/// This is what makes the watch's scoring flow testable at all. The watch target
/// is reachable by no test in this project, so the ordering that used to live in
/// `ScoreView` — send the result before tearing the workout down, clear the
/// saved Match when it is cancelled — could not be asserted. As a list of these
/// it can.
enum MatchEffect: Equatable {
    /// Write the Match to the in-progress store. `MatchPersistence.save` clears
    /// the store instead when the Match is over, so this is also what disposes
    /// of the saved Match at the final point.
    case persist
    /// Drop the saved Match outright — the cancel path, where there is no final
    /// state worth keeping.
    case clearPersisted
    /// Begin the workout for this Match. The Health Monitoring flag is the
    /// screen's to supply: it is watch-session state, not Match state.
    case startWorkout
    /// The point-entered click.
    case haptic
    /// Send the finished Match to the phone. **Must be performed before
    /// `endWorkout`**: the screen snapshots the workout stats while carrying
    /// this out, and the builder those stats come from is gone once the workout
    /// is torn down. Reversed, every finished Match silently loses its calories
    /// and average heart rate.
    case sendResult(state: MatchState, duration: TimeInterval)
    /// End and save the workout.
    case endWorkout
    /// Hand the cancelled Match's elapsed time to the workout adapter, which
    /// applies the discard-versus-save policy (`WorkoutPolicy.cancelDecision`).
    /// The policy is not re-decided here.
    case cancelWorkout(elapsed: TimeInterval)
}

/// The Match currently being scored on the watch: its state, its Undo Stack, and
/// the effects each interaction produces.
///
/// A pure value with no dependencies — no store, no HealthKit, no connectivity
/// session — held by the score screen as view state and mutated in place, the
/// same shape `ScoreEngine` already uses. It sits *above* the scoring engine and
/// re-tests none of its rules; what it owns is what the screen used to decide
/// inline: what gets saved, what clicks, what is sent, and in what order.
struct MatchInProgress {
    /// The Match as it stands. Read by the screen for display; only the
    /// interactions below change it.
    private(set) var state: MatchState

    /// The Undo Stack: the earlier states of this Match, kept only so a player
    /// can take back a point entered by mistake.
    private(set) var undoStack: [MatchState] = []

    /// Starts a fresh Match, stamping the synced Team Names at match start.
    static func new(
        matchType: MatchType,
        initialServer: Team,
        teamAName: String = "",
        teamBName: String = ""
    ) -> MatchInProgress {
        MatchInProgress(state: .newMatch(
            matchType: matchType,
            initialServer: initialServer,
            teamAName: teamAName,
            teamBName: teamBName
        ))
    }

    /// Resumes a Match restored from the in-progress store.
    ///
    /// **A resumed Match has no Undo Stack** — this is a decision, not an
    /// oversight. The store persists the Match state alone; earlier states were
    /// never written, and persisting them would mean writing a blob containing
    /// the whole growing Game Log on every single point. So the first point
    /// entered after a resume cannot be taken back, and the undo arrow correctly
    /// shows itself as disabled until there is something to undo.
    static func restored(_ state: MatchState) -> MatchInProgress {
        MatchInProgress(state: state)
    }

    private init(state: MatchState) {
        self.state = state
    }

    /// Whether the undo arrow has anything to undo. False on a fresh Match and
    /// on a resumed one.
    var canUndo: Bool { !undoStack.isEmpty }

    /// The screen appearing on a Match, new or resumed. Saving first means a
    /// Match survives a kill from its very first frame.
    func start() -> [MatchEffect] {
        [.persist, .startWorkout]
    }

    /// A point to `team`. Saves immediately — no point is ever lost between taps
    /// — and, when that point ended the Match, returns the send and the workout
    /// teardown itself rather than leaving the screen to notice the Match ended.
    mutating func awardPoint(to team: Team, now: Date = Date()) -> [MatchEffect] {
        undoStack.append(state)
        ScoreEngine.awardPoint(to: team, state: &state)

        var effects: [MatchEffect] = [.persist, .haptic]
        if state.isMatchOver {
            effects.append(.sendResult(
                state: state,
                duration: now.timeIntervalSince(state.matchStartDate)
            ))
            effects.append(.endWorkout)
        }
        return effects
    }

    /// Takes back the last point. Saved too, so a crash right after an undo
    /// doesn't resurrect the point just taken back. Nothing to undo means no
    /// effects at all.
    mutating func undo() -> [MatchEffect] {
        guard let previous = undoStack.popLast() else { return [] }
        state = previous
        return [.persist, .haptic]
    }

    /// Abandoning the Match. The workout adapter decides whether the exercise
    /// was real; the saved Match is cleared either way, so the next launch never
    /// offers to resume a Match the player walked away from.
    func cancel(now: Date = Date()) -> [MatchEffect] {
        [
            .cancelWorkout(elapsed: now.timeIntervalSince(state.matchStartDate)),
            .clearPersisted
        ]
    }
}
