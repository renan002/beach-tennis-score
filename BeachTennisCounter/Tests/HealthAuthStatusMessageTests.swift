import XCTest
@testable import BeachTennisCounter

final class HealthAuthStatusMessageTests: XCTestCase {

    // MARK: - Round-trip

    func test_roundtrip_eachStatus() {
        for status in HealthAuthStatus.allCases {
            let context = HealthAuthStatusMessage(status: status).toApplicationContext()
            XCTAssertEqual(HealthAuthStatusMessage.status(from: context), status)
        }
    }

    func test_toApplicationContext_usesSharedKey() {
        let context = HealthAuthStatusMessage(status: .granted).toApplicationContext()
        XCTAssertEqual(context[WatchMessageKey.healthAuthStatus] as? String, "granted")
        XCTAssertEqual(context.count, 1)
    }

    // MARK: - Absent / unknown values leave the phone's status untouched (nil)

    func test_status_missingKey_returnsNil() {
        XCTAssertNil(HealthAuthStatusMessage.status(from: [:]))
    }

    func test_status_unknownValue_returnsNil() {
        XCTAssertNil(HealthAuthStatusMessage.status(from: [WatchMessageKey.healthAuthStatus: "bogus"]))
    }

    func test_status_wrongType_returnsNil() {
        XCTAssertNil(HealthAuthStatusMessage.status(from: [WatchMessageKey.healthAuthStatus: 42]))
    }
}
