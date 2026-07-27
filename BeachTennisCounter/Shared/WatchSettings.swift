import Foundation

/// The phone-configurable settings the watch consumes, as a single value.
///
/// Counterpart to `MatchResultPayload` for the iPhone → Watch application-context
/// path. The context is a full replacement, never a partial merge: the phone always
/// writes every key, so a missing key means a garbled context and decodes to the
/// default below rather than leaving a stale value applied on the watch.
struct WatchSettings: Sendable, Equatable {
    static let defaultTeamAColorHex = "E74C3C"
    static let defaultTeamBColorHex = "5B8DEF"
    static let defaultSportSetting = "beachTennis"
    /// Default team names are empty — the watch serve buttons fall back to the
    /// localized "Team A"/"Team B" literals when a name is empty.
    static let defaultTeamAName = ""
    static let defaultTeamBName = ""
    static let defaultHealthMonitoringEnabled = true

    let teamAColorHex: String
    let teamBColorHex: String
    let sportSetting: String
    let teamAName: String
    let teamBName: String
    let healthMonitoringEnabled: Bool

    init(
        teamAColorHex: String,
        teamBColorHex: String,
        sportSetting: String,
        teamAName: String = defaultTeamAName,
        teamBName: String = defaultTeamBName,
        healthMonitoringEnabled: Bool = defaultHealthMonitoringEnabled
    ) {
        self.teamAColorHex = teamAColorHex
        self.teamBColorHex = teamBColorHex
        self.sportSetting = sportSetting
        self.teamAName = teamAName
        self.teamBName = teamBName
        self.healthMonitoringEnabled = healthMonitoringEnabled
    }

    func toApplicationContext() -> [String: Any] {
        [
            WatchMessageKey.teamAColor: teamAColorHex,
            WatchMessageKey.teamBColor: teamBColorHex,
            WatchMessageKey.sportSetting: sportSetting,
            WatchMessageKey.teamAName: teamAName,
            WatchMessageKey.teamBName: teamBName,
            WatchMessageKey.healthMonitoring: healthMonitoringEnabled
        ]
    }

    /// Decodes a settings context. Always succeeds: a missing or garbled key falls
    /// back to the default above. Callers decide whether a context is worth applying
    /// at all — an empty context means "no settings received", not "reset to defaults".
    static func from(_ dict: [String: Any]) -> WatchSettings {
        WatchSettings(
            teamAColorHex: dict[WatchMessageKey.teamAColor] as? String ?? defaultTeamAColorHex,
            teamBColorHex: dict[WatchMessageKey.teamBColor] as? String ?? defaultTeamBColorHex,
            sportSetting: dict[WatchMessageKey.sportSetting] as? String ?? defaultSportSetting,
            teamAName: dict[WatchMessageKey.teamAName] as? String ?? defaultTeamAName,
            teamBName: dict[WatchMessageKey.teamBName] as? String ?? defaultTeamBName,
            healthMonitoringEnabled: dict[WatchMessageKey.healthMonitoring] as? Bool ?? defaultHealthMonitoringEnabled
        )
    }
}
