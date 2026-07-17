import XCTest
@testable import BeachTennisCounter

final class MatchTypeLabelTests: XCTestCase {

    func test_gameLabel_beachTennis_displaysGamesAsSets() {
        XCTAssertEqual(MatchType.beachTennis.gameLabel(1), "Set 1")
        XCTAssertEqual(MatchType.beachTennis.gameLabel(12), "Set 12")
    }

    func test_gameLabel_tennis_displaysGamesAsGames() {
        XCTAssertEqual(MatchType.tennis.gameLabel(1), "Game 1")
        XCTAssertEqual(MatchType.tennis.gameLabel(12), "Game 12")
    }

    func test_gamesSectionTitle_followsSport() {
        XCTAssertEqual(MatchType.beachTennis.gamesSectionTitle, "Sets")
        XCTAssertEqual(MatchType.tennis.gamesSectionTitle, "Games")
    }
}
