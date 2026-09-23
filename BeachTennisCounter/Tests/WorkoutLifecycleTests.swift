import XCTest
@testable import BeachTennisCounter

/// The pure state machine behind the WorkoutManager's held starts: the deferred
/// ping start (a non-physical sport must never be held and never revived), and
/// the cancelled/stale authorization cases where a held token must not complete.
/// The watch adapter is untestable from this suite, so the bookkeeping it
/// mirrors is pinned here.
final class WorkoutLifecycleTests: XCTestCase {

    private func token(
        monitoring: Bool = true,
        physical: Bool = true,
        sport: String = MatchType.beachTennis.rawValue
    ) -> WorkoutLifecycle.PendingStart {
        WorkoutLifecycle.PendingStart(
            monitoringEnabled: monitoring,
            sportIsPhysical: physical,
            matchTypeRaw: sport
        )
    }

    // MARK: - resolve: the pure gate, renamed

    func test_resolve_whenEnabledIdleAndNoRecovery_starts() {
        XCTAssertEqual(
            WorkoutLifecycle.resolve(monitoringEnabled: true, sessionRunning: false, recoveryPending: false, sportIsPhysical: true),
            .start
        )
    }

    func test_resolve_whileRecoveryPending_defers() {
        XCTAssertEqual(
            WorkoutLifecycle.resolve(monitoringEnabled: true, sessionRunning: false, recoveryPending: true, sportIsPhysical: true),
            .deferStart
        )
    }

    func test_resolve_nonPhysicalSport_skipsEvenWhileRecoveryPending() {
        // Ping: no workout, and nothing held — a later recovery callback finds no
        // token and cannot revive a start for a sport that never wanted one.
        XCTAssertEqual(
            WorkoutLifecycle.resolve(monitoringEnabled: true, sessionRunning: false, recoveryPending: true, sportIsPhysical: false),
            .skip
        )
    }

    func test_resolve_monitoringOff_orSessionRunning_skips() {
        XCTAssertEqual(
            WorkoutLifecycle.resolve(monitoringEnabled: false, sessionRunning: false, recoveryPending: false, sportIsPhysical: true),
            .skip
        )
        XCTAssertEqual(
            WorkoutLifecycle.resolve(monitoringEnabled: true, sessionRunning: true, recoveryPending: false, sportIsPhysical: true),
            .skip
        )
    }

    // MARK: - canCompleteAuthorization: the stale-authorization guard

    func test_authorizationCompletion_matchingToken_completes() {
        let requested = token()
        XCTAssertTrue(WorkoutLifecycle.canCompleteAuthorization(pending: requested, requested: requested))
    }

    func test_authorizationCompletion_clearedToken_isStale() {
        // Cancel/end clears the token on the main actor before the async prompt
        // completion rejoins — the completion must not start an orphan workout.
        let requested = token()
        XCTAssertFalse(WorkoutLifecycle.canCompleteAuthorization(pending: nil, requested: requested))
    }

    func test_authorizationCompletion_differentSportToken_isStale() {
        // A superseding match (different sport) invalidates the older request.
        let requested = token(sport: MatchType.tennis.rawValue)
        let other = token(sport: MatchType.pingPong.rawValue)
        XCTAssertFalse(WorkoutLifecycle.canCompleteAuthorization(pending: other, requested: requested))
    }

    func test_authorizationCompletion_pingToken_neverStartsWorkout() {
        // The adapter only sets a pending token for a physical sport, so a ping
        // token is impossible — but if one ever exists, it must never complete.
        let ping = token(physical: false, sport: MatchType.pingPong.rawValue)
        XCTAssertFalse(WorkoutLifecycle.canCompleteAuthorization(pending: ping, requested: ping))
    }

    // MARK: - shouldReplayAfterRecovery: the deferred-ping / cancelled-Match guard

    func test_recoveryReplay_matchingToken_withMonitoringOn_replays() {
        let pending = token()
        XCTAssertTrue(WorkoutLifecycle.shouldReplayAfterRecovery(
            pending: pending, monitoringEnabled: true, sessionRunning: false))
    }

    func test_recoveryReplay_noToken_doesNotReplay() {
        XCTAssertFalse(WorkoutLifecycle.shouldReplayAfterRecovery(
            pending: nil, monitoringEnabled: true, sessionRunning: false))
    }

    func test_recoveryReplay_nonPhysicalToken_doesNotReplay() {
        // A ping start is never held (see resolve), but the guard still refuses a
        // non-physical token — belt and braces against a stale hold.
        let ping = token(physical: false, sport: MatchType.pingPong.rawValue)
        XCTAssertFalse(WorkoutLifecycle.shouldReplayAfterRecovery(
            pending: ping, monitoringEnabled: true, sessionRunning: false))
    }

    func test_recoveryReplay_cancelledMatch_noToken_doesNotReplay() {
        // Cancel/end cleared the token; a late recovery callback sees nil.
        XCTAssertFalse(WorkoutLifecycle.shouldReplayAfterRecovery(
            pending: nil, monitoringEnabled: true, sessionRunning: false))
    }

    func test_recoveryReplay_monitoringToggledOff_doesNotReplay() {
        let pending = token()
        XCTAssertFalse(WorkoutLifecycle.shouldReplayAfterRecovery(
            pending: pending, monitoringEnabled: false, sessionRunning: false))
    }

    func test_recoveryReplay_sessionAlreadyRunning_doesNotReplay() {
        let pending = token()
        XCTAssertFalse(WorkoutLifecycle.shouldReplayAfterRecovery(
            pending: pending, monitoringEnabled: true, sessionRunning: true))
    }

    // MARK: - The token carries its sport

    func test_pendingToken_carriesSportAndMonitoring() {
        let ping = token(monitoring: true, physical: true, sport: MatchType.pingPong.rawValue)
        XCTAssertEqual(ping.matchTypeRaw, MatchType.pingPong.rawValue)
        XCTAssertTrue(ping.monitoringEnabled)
        XCTAssertTrue(ping.sportIsPhysical)
    }
}