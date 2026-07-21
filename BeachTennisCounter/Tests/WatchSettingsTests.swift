import XCTest
@testable import BeachTennisCounter

final class WatchSettingsTests: XCTestCase {

    private func makeSettings(
        teamAColorHex: String = "E74C3C",
        teamBColorHex: String = "5B8DEF",
        sportSetting: String = "beachTennis",
        healthMonitoringEnabled: Bool = true
    ) -> WatchSettings {
        WatchSettings(teamAColorHex: teamAColorHex,
                      teamBColorHex: teamBColorHex,
                      sportSetting: sportSetting,
                      healthMonitoringEnabled: healthMonitoringEnabled)
    }

    // MARK: - Round-trip

    func test_roundtrip_teamColors() {
        let settings = makeSettings(teamAColorHex: "2ECC71", teamBColorHex: "9B59B6")
        let decoded = WatchSettings.from(settings.toApplicationContext())
        XCTAssertEqual(decoded.teamAColorHex, "2ECC71")
        XCTAssertEqual(decoded.teamBColorHex, "9B59B6")
    }

    func test_roundtrip_sportSetting() {
        let settings = makeSettings(sportSetting: "tennis")
        let decoded = WatchSettings.from(settings.toApplicationContext())
        XCTAssertEqual(decoded.sportSetting, "tennis")
    }

    func test_roundtrip_preservesWholeValue() {
        let settings = makeSettings(teamAColorHex: "E67E22",
                                    teamBColorHex: "2ECC71",
                                    sportSetting: "multiple")
        let decoded = WatchSettings.from(settings.toApplicationContext())
        XCTAssertEqual(decoded, settings)
    }

    // MARK: - Encoding uses the shared message keys

    func test_toApplicationContext_usesSharedKeys() {
        let context = makeSettings(teamAColorHex: "AABBCC",
                                   teamBColorHex: "DDEEFF",
                                   sportSetting: "tennis").toApplicationContext()
        XCTAssertEqual(context[WatchMessageKey.teamAColor] as? String, "AABBCC")
        XCTAssertEqual(context[WatchMessageKey.teamBColor] as? String, "DDEEFF")
        XCTAssertEqual(context[WatchMessageKey.sportSetting] as? String, "tennis")
        XCTAssertEqual(context.count, 4)
    }

    // MARK: - Missing fields fall back to defaults (full-trio replace semantics)

    func test_from_missingSport_usesDefaultSport() {
        let decoded = WatchSettings.from([
            WatchMessageKey.teamAColor: "2ECC71",
            WatchMessageKey.teamBColor: "9B59B6"
        ])
        XCTAssertEqual(decoded.sportSetting, "beachTennis")
        XCTAssertEqual(decoded.teamAColorHex, "2ECC71")
    }

    func test_from_missingColors_usesDefaultColors() {
        let decoded = WatchSettings.from([WatchMessageKey.sportSetting: "tennis"])
        XCTAssertEqual(decoded.teamAColorHex, "E74C3C")
        XCTAssertEqual(decoded.teamBColorHex, "5B8DEF")
        XCTAssertEqual(decoded.sportSetting, "tennis")
    }

    func test_from_wrongValueType_usesDefault() {
        let decoded = WatchSettings.from([
            WatchMessageKey.teamAColor: 42,
            WatchMessageKey.teamBColor: "9B59B6",
            WatchMessageKey.sportSetting: "tennis"
        ])
        XCTAssertEqual(decoded.teamAColorHex, "E74C3C")
        XCTAssertEqual(decoded.teamBColorHex, "9B59B6")
    }

    func test_from_emptyDict_usesAllDefaults() {
        let decoded = WatchSettings.from([:])
        XCTAssertEqual(decoded, makeSettings())
    }

    // MARK: - Health Monitoring

    func test_roundtrip_healthMonitoring() {
        let decoded = WatchSettings.from(makeSettings(healthMonitoringEnabled: false).toApplicationContext())
        XCTAssertFalse(decoded.healthMonitoringEnabled)
    }

    func test_from_missingHealthMonitoring_defaultsTrue() {
        let decoded = WatchSettings.from([
            WatchMessageKey.teamAColor: "2ECC71",
            WatchMessageKey.teamBColor: "9B59B6",
            WatchMessageKey.sportSetting: "tennis"
        ])
        XCTAssertTrue(decoded.healthMonitoringEnabled)
    }

    func test_from_emptyDict_healthMonitoringDefaultsTrue() {
        XCTAssertTrue(WatchSettings.from([:]).healthMonitoringEnabled)
    }
}
