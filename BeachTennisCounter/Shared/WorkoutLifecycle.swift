import Foundation

/// The pure decision core for a workout start that may be deferred or held
/// waiting on authorization.
///
/// The watch target is unreachable by this project's unit tests, so the
/// WorkoutManager adapter's deferred-start bookkeeping — a start held while
/// crash recovery or HealthKit authorization is in flight, and the cases where
/// a held start must not complete — is mirrored here as a pure state machine.
/// The adapter translates these verdicts into HealthKit calls, the same split it
/// already makes for `WorkoutPolicy`.
///
/// The start gating itself belongs to `WorkoutPolicy` (the scoring-lane core);
/// this node adds the *stateful* parts policy cannot express: a held start that
/// carries its sport by value, and the checks that keep a held start from
/// spinning up a workout after the Match that asked for it is gone.
enum WorkoutLifecycle {

    enum Verdict: Equatable, Sendable {
        /// Start now: no recovery in flight, no session running, monitoring on.
        case start
        /// Nothing to do — the sport is not physical, monitoring is off, or a
        /// session is already running. Nothing is held.
        case skip
        /// Hold the start and replay it once recovery resolves.
        case deferStart
    }

    /// A start that the adapter is holding while recovery or authorization is in
    /// flight. Carries everything a replay needs by value — including the sport
    /// — so a held token can never be replayed under the wrong sport, and so an
    /// authorization completion from a cancelled Match cannot start an orphan
    /// workout.
    struct PendingStart: Equatable, Sendable {
        let monitoringEnabled: Bool
        let sportIsPhysical: Bool
        /// The Match's sport token (`MatchType.rawValue`), a stable storage key.
        /// The adapter maps it onto a HealthKit `HKWorkoutActivityType` when the
        /// start actually happens, so a replayed ping start keeps the ping
        /// activity instead of falling back to `tennis`.
        let matchTypeRaw: String
    }

    /// Resolves a start request against the state the adapter reports.
    ///
    /// The pure gate is `WorkoutPolicy.startDecision`; the verdict is renamed to
    /// the adapter's vocabulary. A held token is *not* consulted here — the
    /// adapter overwrites it on a fresh start and clears it on end/cancel, and
    /// the completion checks below are what stop a stale token from replaying.
    static func resolve(
        monitoringEnabled: Bool,
        sessionRunning: Bool,
        recoveryPending: Bool,
        sportIsPhysical: Bool
    ) -> Verdict {
        switch WorkoutPolicy.startDecision(
            monitoringEnabled: monitoringEnabled,
            sessionRunning: sessionRunning,
            recoveryPending: recoveryPending,
            sportIsPhysical: sportIsPhysical
        ) {
        case .skip:
            return .skip
        case .deferUntilRecovered:
            return .deferStart
        case .start:
            return .start
        }
    }

    /// Whether a start that requested authorization can now go ahead.
    ///
    /// The adapter clears the held token on end/cancel *before* the async
    /// authorization completion rejoins the main actor, so the token this start
    /// captured is the exact signal that the Match still wants a workout. A nil
    /// or different token means the Match was cancelled, ended, or superseded —
    /// beginning a session then would orphan a workout behind the finished
    /// screen. A non-physical request (ping) is refused outright — belt and
    /// braces against a stale hold, mirroring `shouldReplayAfterRecovery`.
    static func canCompleteAuthorization(
        pending: PendingStart?,
        requested: PendingStart
    ) -> Bool {
        guard requested.sportIsPhysical else { return false }
        return pending == requested
    }

    /// Whether a token held through crash recovery may be replayed now that
    /// recovery answered. Recovery runs on the main actor after end/cancel, so a
    /// cancelled Match's token is already nil; this guard is the pure shape of
    /// "the held start may still become a workout".
    static func shouldReplayAfterRecovery(
        pending: PendingStart?,
        monitoringEnabled: Bool,
        sessionRunning: Bool
    ) -> Bool {
        guard let pending, pending.sportIsPhysical else { return false }
        guard pending.monitoringEnabled == monitoringEnabled,
              monitoringEnabled,
              !sessionRunning
        else { return false }
        return true
    }
}