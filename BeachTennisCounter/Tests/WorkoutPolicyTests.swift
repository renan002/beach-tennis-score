import XCTest
@testable import BeachTennisCounter

final class WorkoutPolicyTests: XCTestCase {

    // MARK: - Start gating

    func test_start_whenEnabledAndIdle_attempts() {
        XCTAssertEqual(
            WorkoutPolicy.startDecision(monitoringEnabled: true, sessionRunning: false),
            .start
        )
    }

    func test_start_whenMonitoringOff_skips() {
        XCTAssertEqual(
            WorkoutPolicy.startDecision(monitoringEnabled: false, sessionRunning: false),
            .skip
        )
    }

    func test_start_whenAlreadyRunning_skips() {
        // Idempotence: a re-entered / resumed score screen must not start a second session.
        XCTAssertEqual(
            WorkoutPolicy.startDecision(monitoringEnabled: true, sessionRunning: true),
            .skip
        )
    }

    func test_start_whenOffAndRunning_skips() {
        XCTAssertEqual(
            WorkoutPolicy.startDecision(monitoringEnabled: false, sessionRunning: true),
            .skip
        )
    }

    // MARK: - Cancel threshold

    func test_cancel_belowThreshold_discards() {
        XCTAssertEqual(WorkoutPolicy.cancelDecision(elapsed: 0), .discard)
        XCTAssertEqual(WorkoutPolicy.cancelDecision(elapsed: 119), .discard)
    }

    func test_cancel_atThreshold_saves() {
        XCTAssertEqual(WorkoutPolicy.cancelDecision(elapsed: 120), .save)
    }

    func test_cancel_aboveThreshold_saves() {
        XCTAssertEqual(WorkoutPolicy.cancelDecision(elapsed: 3600), .save)
    }

    // MARK: - Report on change only

    func test_report_whenNoPriorStatus_reports() {
        XCTAssertTrue(WorkoutPolicy.shouldReport(status: .granted, lastReported: nil))
    }

    func test_report_whenStatusChanged_reports() {
        XCTAssertTrue(WorkoutPolicy.shouldReport(status: .denied, lastReported: .granted))
        XCTAssertTrue(WorkoutPolicy.shouldReport(status: .granted, lastReported: .undetermined))
    }

    func test_report_whenStatusUnchanged_doesNotReport() {
        XCTAssertFalse(WorkoutPolicy.shouldReport(status: .granted, lastReported: .granted))
        XCTAssertFalse(WorkoutPolicy.shouldReport(status: .denied, lastReported: .denied))
        XCTAssertFalse(WorkoutPolicy.shouldReport(status: .undetermined, lastReported: .undetermined))
    }
}
