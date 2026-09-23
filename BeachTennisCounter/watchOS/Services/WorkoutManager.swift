import Foundation
import HealthKit
import SwiftUI

/// Owns the watch's HealthKit workout for the duration of a Match: the health
/// store, the `HKWorkoutSession` + `HKLiveWorkoutBuilder`, the idempotence guard,
/// and crash recovery.
///
/// This is the thin HealthKit **adapter** — it translates the pure verdicts from
/// `WorkoutPolicy` into store/session/builder calls and nothing more. The pure
/// parts that are stateful (a held start, its sport, and the cases where it must
/// not complete) live in `WorkoutLifecycle`; the adapter carries them out.
///
/// **Hard requirement:** every HealthKit path degrades silently. If Health data
/// is unavailable, authorization is denied, or any call throws, scoring, undo,
/// and match-over behave exactly as they do without this object.
@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()

    /// Live heart rate in bpm, or `nil` when no workout is running (denied,
    /// monitoring off, unavailable, or no sample yet). `ScoreView`'s readout is
    /// absent while this is `nil`, so the no-workout screen renders as today.
    @Published var currentHeartRate: Double?

    private let healthStore = HKHealthStore()

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    /// The idempotence guard: a re-entered or resumed score screen (or a recovered
    /// session) must not start a second session.
    private var isSessionRunning: Bool { session != nil }

    /// True from launch until `recoverActiveWorkoutSession` answers. A Match start
    /// that lands in this window is held and replayed once recovery resolves —
    /// otherwise a Match resumed right after a force-quit would open a second
    /// workout alongside the recovered one.
    private var isRecoveryPending = true
    /// A start held while recovery is in flight, carrying the Match's own
    /// sport. `nil` once the token is replayed, cleared on end/cancel so no
    /// recovery callback can revive a cancelled Match's workout.
    private var pendingRecoveryStart: WorkoutLifecycle.PendingStart?
    /// A start whose authorization request is still in flight. Cleared on
    /// end/cancel; the completion re-checks it before beginning a session, so a
    /// cancelled Match's authorization completion cannot start an orphan workout.
    private var pendingAuthorizationStart: WorkoutLifecycle.PendingStart?

    private let typesToShare: Set<HKSampleType> = [HKQuantityType.workoutType()]
    private let typesToRead: Set<HKObjectType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.activeEnergyBurned)
    ]

    private override init() {
        super.init()
        recoverActiveSession()
    }

    // MARK: - Lifecycle entry points (called from ScoreView)

    /// Called from `ScoreView.onAppear` for both new and resumed Matches.
    ///
    /// Always reports the current authorization status to the phone (prompt-free,
    /// toggle-independent — so a re-grant is noticed even if the toggle is off —
    /// then, only if `WorkoutLifecycle.resolve` says to begin, requests
    /// authorization on first use and starts a session for the sport the Match
    /// is played under.
    func matchDidStart(
        monitoringEnabled: Bool,
        sportIsPhysical: Bool,
        matchTypeRaw: String
    ) {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        reportCurrentAuthStatus()

        switch WorkoutLifecycle.resolve(
            monitoringEnabled: monitoringEnabled,
            sessionRunning: isSessionRunning,
            recoveryPending: isRecoveryPending,
            sportIsPhysical: sportIsPhysical
        ) {
        case .skip:
            // Nothing starts and nothing is held for *this* Match. A token held
            // from an earlier Match (recovery still pending or an earlier
            // authorization prompt) belongs to a Match that is no longer
            // current — dropping it here stops a stale replay under a Match
            // that never asked for a workout.
            pendingRecoveryStart = nil
            pendingAuthorizationStart = nil
            return
        case .deferStart:
            pendingRecoveryStart = WorkoutLifecycle.PendingStart(
                monitoringEnabled: monitoringEnabled,
                sportIsPhysical: sportIsPhysical,
                matchTypeRaw: matchTypeRaw
            )
            return
        case .start:
            break
        }

        requestAuthorizationAndBegin(monitoringEnabled: monitoringEnabled, sportIsPhysical: sportIsPhysical, matchTypeRaw: matchTypeRaw)
    }

    /// Synchronous snapshot of accumulated stats for the result payload. Read
    /// before the async end/finish so the phone payload never waits on HealthKit.
    /// Returns `nil`s when no workout ran.
    func snapshotStats() -> (activeCalories: Double?, avgHeartRate: Double?) {
        guard let builder else { return (nil, nil) }
        let kcal = builder.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())
        let bpm = builder.statistics(for: HKQuantityType(.heartRate))?
            .averageQuantity()?.doubleValue(for: Self.bpmUnit)
        return (kcal, bpm)
    }

    /// Ends and saves the workout asynchronously. The caller has already sent the
    /// Match result, so a save failure here can't lose the Match.
    func endAndFinish() {
        // A start still waiting on recovery or authorization belongs to the Match
        // that just ended — dropping it keeps a workout from opening behind the
        // finished score screen, whether recovery or the authorization prompt
        // answers later.
        pendingRecoveryStart = nil
        pendingAuthorizationStart = nil
        guard let session, let builder else { return }
        let end = Date()
        session.end()
        self.session = nil
        self.builder = nil
        currentHeartRate = nil
        Task {
            try? await builder.endCollection(at: end)
            _ = try? await builder.finishWorkout()
        }
    }

    /// Applies the cancel policy: below the threshold discard (accidental start),
    /// above it end and save (the exercise was real even if the Match wasn't).
    func cancelWorkout(elapsed: TimeInterval) {
        // The Match is gone — a start still waiting on recovery or a pending
        // authorization prompt is stale and must not replay behind the cancel.
        pendingRecoveryStart = nil
        pendingAuthorizationStart = nil
        guard let session, let builder else { return }
        switch WorkoutPolicy.cancelDecision(elapsed: elapsed) {
        case .discard:
            session.end()
            self.session = nil
            self.builder = nil
            currentHeartRate = nil
            builder.discardWorkout()
        case .save:
            endAndFinish()
        }
    }

    // MARK: - Internals

    // Computed (not stored) and nonisolated so both the @MainActor snapshot and
    // the nonisolated builder delegate can share the one definition.
    private nonisolated static var bpmUnit: HKUnit { HKUnit.count().unitDivided(by: .minute()) }

    private func reportCurrentAuthStatus() {
        WatchSessionManager.shared.reportHealthAuthStatus(mappedAuthStatus())
    }

    /// HealthKit only exposes *share* authorization (read status is deliberately
    /// hidden), which is the best available signal for the phone's toggle.
    private func mappedAuthStatus() -> HealthAuthStatus {
        switch healthStore.authorizationStatus(for: HKQuantityType.workoutType()) {
        case .sharingAuthorized: return .granted
        case .sharingDenied:     return .denied
        default:                 return .undetermined
        }
    }

    private func requestAuthorizationAndBegin(
        monitoringEnabled: Bool,
        sportIsPhysical: Bool,
        matchTypeRaw: String
    ) {
        let requested = WorkoutLifecycle.PendingStart(
            monitoringEnabled: monitoringEnabled,
            sportIsPhysical: sportIsPhysical,
            matchTypeRaw: matchTypeRaw
        )
        pendingAuthorizationStart = requested
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.reportCurrentAuthStatus()
                guard WorkoutLifecycle.canCompleteAuthorization(
                    pending: self.pendingAuthorizationStart,
                    requested: requested
                ) else { return }
                // No-op on denial (design §2): don't spin a session that can never
                // save. Undetermined still begins — the status may resolve mid-match.
                guard self.mappedAuthStatus() != .denied else { return }
                self.beginSession(matchTypeRaw: requested.matchTypeRaw)
            }
        }
    }

    private func beginSession(matchTypeRaw: String) {
        guard session == nil else { return }
        let config = HKWorkoutConfiguration()
        // The sport the Match is actually played under. Ping pong is scored on
        // the watch this release; HealthKit's own `.tableTennis` maps it. Beach
        // and tennis keep the legacy `.tennis` activity.
        config.activityType = activityType(for: matchTypeRaw)
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }
        } catch {
            session = nil
            builder = nil
        }
    }

    private func activityType(for matchTypeRaw: String) -> HKWorkoutActivityType {
        matchTypeRaw == MatchType.pingPong.rawValue ? .tableTennis : .tennis
    }

    private func recoverActiveSession() {
        guard HKHealthStore.isHealthDataAvailable() else {
            isRecoveryPending = false
            return
        }
        healthStore.recoverActiveWorkoutSession { session, _ in
            Task { @MainActor [weak self] in self?.recoveryDidFinish(with: session) }
        }
    }

    /// Closes the recovery window: reattach a surviving session (the resumed Match
    /// keeps its original workout), then replay a Match start that was held while
    /// the lookup was in flight. With a session recovered the replayed start is a
    /// no-op by idempotence; with none it starts a fresh workout as usual.
    ///
    /// The held token is cleared before replaying — a cancelled or ended Match
    /// already invalidated the token on the main actor, so the guard below is
    /// what stops a stale replay. A surviving token replays through the full
    /// authorization path, exactly as the original Match start would have.
    private func recoveryDidFinish(with recovered: HKWorkoutSession?) {
        if let recovered { attach(recovered) }
        isRecoveryPending = false
        guard let pending = pendingRecoveryStart else { return }
        pendingRecoveryStart = nil
        guard WorkoutLifecycle.shouldReplayAfterRecovery(
            pending: pending,
            monitoringEnabled: pending.monitoringEnabled,
            sessionRunning: isSessionRunning
        ) else { return }
        requestAuthorizationAndBegin(
            monitoringEnabled: pending.monitoringEnabled,
            sportIsPhysical: pending.sportIsPhysical,
            matchTypeRaw: pending.matchTypeRaw
        )
    }

    private func attach(_ session: HKWorkoutSession) {
        guard self.session == nil else { return }
        let builder = session.associatedWorkoutBuilder()
        // A recovered builder comes back without a data source, and without one it
        // collects nothing: no `didCollectDataOf`, so no live heart rate and empty
        // end-of-Match stats for the rest of the resumed Match. Collection itself
        // is already running from before the crash — only the source is missing.
        session.delegate = self
        builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: session.workoutConfiguration
        )
        self.session = session
        self.builder = builder
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {}
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let hrType = HKQuantityType(.heartRate)
        guard collectedTypes.contains(hrType) else { return }
        let bpm = workoutBuilder.statistics(for: hrType)?
            .mostRecentQuantity()?
            .doubleValue(for: Self.bpmUnit)
        Task { @MainActor in currentHeartRate = bpm }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}