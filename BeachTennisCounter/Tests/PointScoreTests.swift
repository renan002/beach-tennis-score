import XCTest
@testable import BeachTennisCounter

final class PointScoreTests: XCTestCase {

    func test_display_values() {
        XCTAssertEqual(PointScore.zero.display, "0")
        XCTAssertEqual(PointScore.fifteen.display, "15")
        XCTAssertEqual(PointScore.thirty.display, "30")
        XCTAssertEqual(PointScore.forty.display, "40")
    }

    func test_next_chain() {
        XCTAssertEqual(PointScore.zero.next, .fifteen)
        XCTAssertEqual(PointScore.fifteen.next, .thirty)
        XCTAssertEqual(PointScore.thirty.next, .forty)
        XCTAssertNil(PointScore.forty.next)
    }

    func test_allCases_count() {
        XCTAssertEqual(PointScore.allCases.count, 4)
    }
}
