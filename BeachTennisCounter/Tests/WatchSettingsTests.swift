import XCTest
@testable import BeachTennisCounter

final class WatchSettingsTests: XCTestCase {

    private func makeSettings(
        teamAColorHex: String = "E74C3C",
        teamBColorHex: String = "5B8DEF",
        sportSetting: SportSetting = .beachTennis,
        teamAName: String = "",
        teamBName: String = "",
        healthMonitoringEnabled: Bool = true,
        rulesetsBlob: [String: Data] = [:]
    ) -> WatchSettings {
        WatchSettings(teamAColorHex: teamAColorHex,
                      teamBColorHex: teamBColorHex,
                      sportSetting: sportSetting,
                      teamAName: teamAName,
                      teamBName: teamBName,
                      healthMonitoringEnabled: healthMonitoringEnabled,
                      rulesetsBlob: rulesetsBlob)
    }

    // MARK: - Round-trip

    func test_roundtrip_teamColors() {
        let settings = makeSettings(teamAColorHex: "2ECC71", teamBColorHex: "9B59B6")
        let decoded = WatchSettings.from(settings.toApplicationContext())
        XCTAssertEqual(decoded.teamAColorHex, "2ECC71")
        XCTAssertEqual(decoded.teamBColorHex, "9B59B6")
    }

    func test_roundtrip_sportSetting() {
        let settings = makeSettings(sportSetting: .tennis)
        let decoded = WatchSettings.from(settings.toApplicationContext())
        XCTAssertEqual(decoded.sportSetting, .tennis)
    }

    func test_roundtrip_teamNames() {
        let settings = makeSettings(teamAName: "Ana & Bia", teamBName: "Cadu & Dedé")
        let decoded = WatchSettings.from(settings.toApplicationContext())
        XCTAssertEqual(decoded.teamAName, "Ana & Bia")
        XCTAssertEqual(decoded.teamBName, "Cadu & Dedé")
    }

    func test_roundtrip_preservesWholeValue() {
        let settings = makeSettings(teamAColorHex: "E67E22",
                                    teamBColorHex: "2ECC71",
                                    sportSetting: .multiple)
        let decoded = WatchSettings.from(settings.toApplicationContext())
        XCTAssertEqual(decoded, settings)
    }

    // MARK: - Encoding uses the shared message keys

    func test_toApplicationContext_usesSharedKeys() {
        let context = makeSettings(teamAColorHex: "AABBCC",
                                   teamBColorHex: "DDEEFF",
                                   sportSetting: .tennis,
                                   teamAName: "Ana",
                                   teamBName: "Bia").toApplicationContext()
        XCTAssertEqual(context[WatchMessageKey.teamAColor] as? String, "AABBCC")
        XCTAssertEqual(context[WatchMessageKey.teamBColor] as? String, "DDEEFF")
        XCTAssertEqual(context[WatchMessageKey.sportSetting] as? String, "tennis")
        XCTAssertEqual(context[WatchMessageKey.teamAName] as? String, "Ana")
        XCTAssertEqual(context[WatchMessageKey.teamBName] as? String, "Bia")
        XCTAssertEqual(context.count, 6)
    }

    // MARK: - Missing fields fall back to defaults (full-trio replace semantics)

    func test_from_missingSport_usesDefaultSport() {
        let decoded = WatchSettings.from([
            WatchMessageKey.teamAColor: "2ECC71",
            WatchMessageKey.teamBColor: "9B59B6"
        ])
        XCTAssertEqual(decoded.sportSetting, .beachTennis)
        XCTAssertEqual(decoded.teamAColorHex, "2ECC71")
    }

    /// The context carries the sport as a bare token, so a value from a future
    /// build — or a garbled one — has to land somewhere. It lands on the default.
    func test_from_unrecognizedSportToken_usesDefaultSport() {
        let decoded = WatchSettings.from([WatchMessageKey.sportSetting: "volleyball"])
        XCTAssertEqual(decoded.sportSetting, WatchSettings.defaultSportSetting)
    }

    func test_from_missingColors_usesDefaultColors() {
        let decoded = WatchSettings.from([WatchMessageKey.sportSetting: "tennis"])
        XCTAssertEqual(decoded.teamAColorHex, "E74C3C")
        XCTAssertEqual(decoded.teamBColorHex, "5B8DEF")
        XCTAssertEqual(decoded.sportSetting, .tennis)
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

    func test_from_missingNames_usesEmptyDefaults() {
        let decoded = WatchSettings.from([
            WatchMessageKey.teamAColor: "2ECC71",
            WatchMessageKey.teamBColor: "9B59B6",
            WatchMessageKey.sportSetting: "tennis"
        ])
        XCTAssertEqual(decoded.teamAName, "")
        XCTAssertEqual(decoded.teamBName, "")
    }

    func test_from_wrongNameType_usesEmptyDefault() {
        let decoded = WatchSettings.from([
            WatchMessageKey.teamAName: 42,
            WatchMessageKey.teamBName: "Bia"
        ])
        XCTAssertEqual(decoded.teamAName, "")
        XCTAssertEqual(decoded.teamBName, "Bia")
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

    // MARK: - Ruleset blob: full replacement, sport mismatch, stale avoidance

    func test_ruleset_roundtrip() {
        let rules = Ruleset.pingPong(PingPongRuleset(
            identifier: UUID(), name: "Oficial", pointsTarget: 11,
            bestOf: 5, serveMode: .every2
        ))
        let settings = makeSettings(rulesetsBlob: [MatchType.pingPong.rawValue: try! JSONEncoder().encode(rules)])
        let decoded = WatchSettings.from(settings.toApplicationContext())

        XCTAssertEqual(decoded.ruleset(for: .pingPong), rules)
    }

    /// Missing or undecodable entries resolve to the sport's preset — a stale
    /// decoded value must never survive a garbled context.
    func test_ruleset_missingEntry_fallsBackToPreset() {
        let settings = WatchSettings.from([
            WatchMessageKey.teamAColor: "2ECC71",
            WatchMessageKey.teamBColor: "9B59B6"
        ])
        XCTAssertEqual(settings.ruleset(for: .pingPong), Ruleset.preset(for: .pingPong))
    }

    func test_ruleset_garbledEntry_fallsBackToPreset() {
        let settings = makeSettings(rulesetsBlob: [MatchType.pingPong.rawValue: Data([0x00, 0xFF])])
        XCTAssertEqual(settings.ruleset(for: .pingPong), Ruleset.preset(for: .pingPong))
    }

    /// Full replacement semantics: a blob entry carrying another sport's value
    /// must not be applied to the asked sport — the preset is the only safe
    /// answer, never a cross-sport decode.
    func test_ruleset_wrongSportEntry_fallsBackToPreset() {
        let tennis = Ruleset.preset(for: .tennis)
        let blob = [MatchType.pingPong.rawValue: try! JSONEncoder().encode(tennis)]
        let decoded = WatchSettings.from(
            WatchSettings(teamAColorHex: "E74C3C", teamBColorHex: "5B8DEF",
                          sportSetting: .beachTennis, rulesetsBlob: blob).toApplicationContext()
        )
        XCTAssertEqual(decoded.ruleset(for: .pingPong), Ruleset.preset(for: .pingPong))
    }

    func test_ruleset_forOtherSport_keepsPreset() {
        let ping = Ruleset.pingPong(.oficial)
        let settings = makeSettings(rulesetsBlob: [MatchType.pingPong.rawValue: try! JSONEncoder().encode(ping)])
        let decoded = WatchSettings.from(settings.toApplicationContext())
        XCTAssertEqual(decoded.ruleset(for: .beachTennis), Ruleset.preset(for: .beachTennis))
    }
}
