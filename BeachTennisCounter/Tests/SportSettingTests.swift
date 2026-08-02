import XCTest
@testable import BeachTennisCounter

/// The sport setting is persisted on the phone and travels to the watch as a
/// bare token, so the two things worth pinning down are what each stored token
/// decodes to — including a token no build ever wrote — and what each case says
/// the watch should do with it.
final class SportSettingTests: XCTestCase {

    // MARK: - Raw values are storage keys

    /// Shipped builds persisted these exact strings. Change one and a player
    /// who set the watch to Tennis or to Vários silently lands on Beach Tennis.
    func testRawValuesAreTheTokensShippedBuildsPersist() {
        XCTAssertEqual(SportSetting.beachTennis.rawValue, "beachTennis")
        XCTAssertEqual(SportSetting.tennis.rawValue, "tennis")
        XCTAssertEqual(SportSetting.multiple.rawValue, "multiple")
    }

    // MARK: - Decoding a stored token

    func testDecodingEachStoredToken() {
        XCTAssertEqual(SportSetting(storedToken: "beachTennis"), .beachTennis)
        XCTAssertEqual(SportSetting(storedToken: "tennis"), .tennis)
        XCTAssertEqual(SportSetting(storedToken: "multiple"), .multiple)
    }

    /// Anything unrecognised — a token from a future build, a garbled context,
    /// a typo — decodes to the default rather than failing. There is no screen
    /// that can report "unknown sport", so the fallback is the whole handling.
    func testDecodingAnUnrecognizedTokenFallsBackToTheDefault() {
        XCTAssertEqual(SportSetting(storedToken: "pingPong"), .default)
        XCTAssertEqual(SportSetting(storedToken: ""), .default)
        XCTAssertEqual(SportSetting.default, .beachTennis)
    }

    // MARK: - What the watch does at a new match

    func testStartSportPerCase() {
        XCTAssertEqual(SportSetting.beachTennis.startSport, .beachTennis)
        XCTAssertEqual(SportSetting.tennis.startSport, .tennis)
        XCTAssertNil(SportSetting.multiple.startSport)
    }

    /// Vários is exactly the case with no sport to start — the two answers are
    /// one decision, so asking either way must never disagree.
    func testAsksBeforeEachMatchOnlyForMultiple() {
        XCTAssertFalse(SportSetting.beachTennis.asksBeforeEachMatch)
        XCTAssertFalse(SportSetting.tennis.asksBeforeEachMatch)
        XCTAssertTrue(SportSetting.multiple.asksBeforeEachMatch)

        for setting in SportSetting.allCases {
            XCTAssertEqual(setting.asksBeforeEachMatch, setting.startSport == nil)
        }
    }

    // MARK: - Copy

    func testEveryCaseHasADisplayNameAndAFooter() {
        for setting in SportSetting.allCases {
            XCTAssertFalse(setting.displayName.isEmpty)
            XCTAssertFalse(setting.settingsFooter.isEmpty)
        }
    }

    /// The picker is built from `allCases`, so a case that stopped being listed
    /// would disappear from Settings without any other test noticing.
    func testAllCasesListsTheThreeSettings() {
        XCTAssertEqual(SportSetting.allCases, [.beachTennis, .tennis, .multiple])
    }
}
