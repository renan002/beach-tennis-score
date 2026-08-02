import Foundation

/// Which sport the watch plays, as chosen once in the iPhone settings.
///
/// Distinct from `MatchType`, which is the sport a *match* is actually being
/// scored under: this is the standing preference, and one of its cases picks no
/// sport at all. It owns everything that used to be a `switch` on a bare string
/// — decoding, the sport to start, whether the watch asks first, and the copy.
///
/// The raw values are storage keys: they are written to `UserDefaults` on the
/// phone and travel to the watch in the application context. Shipped builds
/// persisted them, so they are never localized and never renamed.
enum SportSetting: String, Codable, Sendable, CaseIterable {
    case beachTennis = "beachTennis"
    case tennis = "tennis"
    /// Vários — the watch asks which sport before each match instead of playing
    /// one fixed sport. Named in English like the other domain types, following
    /// the Cartão de Resultado and Estatísticas precedent.
    case multiple = "multiple"

    /// What an unset or unrecognised setting means. Beach tennis is the app's
    /// home sport, so this is also the safest thing to fall back to.
    static let `default` = SportSetting.beachTennis

    /// Decodes a token read out of storage or off the wire. Always succeeds:
    /// anything unrecognised is the default, because no screen can act on
    /// "unknown sport" and refusing to start a match would be worse than
    /// starting the usual one.
    init(storedToken: String) {
        self = SportSetting(rawValue: storedToken) ?? .default
    }

    /// The sport a new match starts under, or `nil` when the player is asked
    /// first. The watch's new-match router is this one question.
    var startSport: MatchType? {
        switch self {
        case .beachTennis: return .beachTennis
        case .tennis:      return .tennis
        case .multiple:    return nil
        }
    }

    /// Whether the watch asks which sport before each match — the same decision
    /// as `startSport`, read from the other side.
    var asksBeforeEachMatch: Bool { startSport == nil }

    var displayName: String {
        switch self {
        case .beachTennis: return String(localized: "Beach Tennis")
        case .tennis:      return String(localized: "Tennis")
        case .multiple:    return String(localized: "Multiple")
        }
    }

    /// What the Settings picker's footer promises this setting will do.
    var settingsFooter: String {
        switch self {
        case .beachTennis: return String(localized: "The Watch will always start a Beach Tennis match.")
        case .tennis:      return String(localized: "The Watch will always start a Tennis match.")
        case .multiple:    return String(localized: "The Watch will ask which sport before each match.")
        }
    }
}
