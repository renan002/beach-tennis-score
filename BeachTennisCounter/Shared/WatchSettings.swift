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

    let teamAColorHex: String
    let teamBColorHex: String
    let sportSetting: String

    func toApplicationContext() -> [String: Any] {
        [
            WatchMessageKey.teamAColor: teamAColorHex,
            WatchMessageKey.teamBColor: teamBColorHex,
            WatchMessageKey.sportSetting: sportSetting
        ]
    }

    static func from(_ dict: [String: Any]) -> WatchSettings? {
        WatchSettings(
            teamAColorHex: dict[WatchMessageKey.teamAColor] as? String ?? defaultTeamAColorHex,
            teamBColorHex: dict[WatchMessageKey.teamBColor] as? String ?? defaultTeamBColorHex,
            sportSetting: dict[WatchMessageKey.sportSetting] as? String ?? defaultSportSetting
        )
    }
}
