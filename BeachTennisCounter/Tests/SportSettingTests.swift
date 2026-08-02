import XCTest
@testable import BeachTennisCounter

/// The Sport setting's own seam: decoding the persisted token, and the two
/// verdicts that used to be a `switch` on string literals inside the watch's
/// new-Match router — where no test could reach them.
final class SportSettingTests: XCTestCase {

    // MARK: - Persisted tokens

    /// The tokens are storage keys written by shipped builds. Changing one
    /// silently resets every install that had chosen it, so they are pinned
    /// here literally rather than derived from the cases.
    func test_rawValues_areTheShippedTokens() {
        XCTAssertEqual(SportSetting.beachTennis.rawValue, "beachTennis")
        XCTAssertEqual(SportSetting.tennis.rawValue, "tennis")
        XCTAssertEqual(SportSetting.multiple.rawValue, "multiple")
    }

    func test_stored_decodesEveryToken() {
        for setting in SportSetting.allCases {
            XCTAssertEqual(SportSetting.stored(setting.rawValue), setting)
        }
    }

    func test_stored_emptyToken_fallsBackToDefault() {
        XCTAssertEqual(SportSetting.stored(""), .default)
    }

    func test_stored_unknownToken_fallsBackToDefault() {
        XCTAssertEqual(SportSetting.stored("pingPong"), .default)
        XCTAssertEqual(SportSetting.stored("BEACHTENNIS"), .default)
    }

    func test_default_isBeachTennis() {
        XCTAssertEqual(SportSetting.default, .beachTennis)
    }

    /// The wire default and the type's default are the same value — the watch
    /// falls back to the same sport whether the key is missing from the context
    /// or carries a token it doesn't know.
    func test_default_matchesTheSettingsWireDefault() {
        XCTAssertEqual(SportSetting.default.rawValue, WatchSettings.defaultSportSetting)
    }

    // MARK: - New-Match routing

    func test_startingMatchType_singleSport_startsThatSport() {
        XCTAssertEqual(SportSetting.beachTennis.startingMatchType, .beachTennis)
        XCTAssertEqual(SportSetting.tennis.startingMatchType, .tennis)
    }

    /// Vários settles nothing in advance — the watch has no Match type to start
    /// with and shows the sport picker instead.
    func test_startingMatchType_multiple_isAbsent() {
        XCTAssertNil(SportSetting.multiple.startingMatchType)
    }

    func test_asksBeforeEachMatch_onlyForMultiple() {
        XCTAssertTrue(SportSetting.multiple.asksBeforeEachMatch)
        XCTAssertFalse(SportSetting.beachTennis.asksBeforeEachMatch)
        XCTAssertFalse(SportSetting.tennis.asksBeforeEachMatch)
    }

    // MARK: - Copy

    /// Every case is offered in the picker with copy of its own — a case added
    /// without a footer would silently ship a blank explanation.
    func test_everyCase_hasDisplayNameAndFooter() {
        for setting in SportSetting.allCases {
            XCTAssertFalse(setting.displayName.isEmpty, "\(setting) has no display name")
            XCTAssertFalse(setting.settingsFooter.isEmpty, "\(setting) has no footer")
        }
    }
}
