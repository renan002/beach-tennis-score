import Foundation

/// The watch app's HealthKit authorization state, as a wire-safe value.
///
/// A pure mirror of `HKAuthorizationStatus` with no HealthKit import, so it can
/// travel the watch→phone application-context channel and be unit-tested. The
/// `WorkoutManager` HealthKit adapter maps `HKAuthorizationStatus` onto this;
/// the phone persists the last-known value to drive the Settings toggle.
enum HealthAuthStatus: String, Sendable, Equatable, CaseIterable {
    case undetermined
    case granted
    case denied
}

/// Verdict for whether a workout session should be started at a Match start.
enum WorkoutStartDecision: Equatable {
    case start
    case skip
    /// Crash recovery hasn't answered yet — hold the start until it does, so a
    /// resumed Match reattaches its original session instead of opening a second one.
    case deferUntilRecovered
}

/// Verdict for what to do with a workout when a Match is cancelled.
enum WorkoutCancelDecision: Equatable {
    /// Below the threshold — an accidental start, discard so no junk lands in Health.
    case discard
    /// Above the threshold — the exercise was real, end and save even though the Match wasn't finished.
    case save
}

/// The pure decision core behind the workout lifecycle. No HealthKit, no side
/// effects — the `WorkoutManager` adapter translates these verdicts into store,
/// session, and builder calls. Everything here is unit-tested; the adapter is not.
enum WorkoutPolicy {
    /// Cancel below this many seconds of elapsed play discards the workout.
    static let cancelDiscardThreshold: TimeInterval = 120

    /// Whether to start a session at a Match start.
    ///
    /// Skips when Health Monitoring is off (never touch HealthKit, never prompt)
    /// or when a session is already running (idempotence — a re-entered or
    /// resumed score screen must not start a second session). Defers while crash
    /// recovery is still in flight: the lookup is async, so starting now is how a
    /// Match resumed after a force-quit would end up with two workouts.
    static func startDecision(
        monitoringEnabled: Bool,
        sessionRunning: Bool,
        recoveryPending: Bool
    ) -> WorkoutStartDecision {
        guard monitoringEnabled, !sessionRunning else { return .skip }
        return recoveryPending ? .deferUntilRecovered : .start
    }

    /// Whether a cancelled Match's workout should be discarded or saved.
    static func cancelDecision(elapsed: TimeInterval) -> WorkoutCancelDecision {
        elapsed < cancelDiscardThreshold ? .discard : .save
    }

    /// Whether a freshly observed auth status should be pushed to the phone.
    /// Reports on change only — an unchanged status is never re-sent.
    static func shouldReport(status: HealthAuthStatus, lastReported: HealthAuthStatus?) -> Bool {
        status != lastReported
    }
}
