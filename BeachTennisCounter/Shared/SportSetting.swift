import Foundation

/// The player's Sport setting: which sport the watch starts a Match in, chosen
/// once on the phone and synced to the watch.
///
/// The `String` raw values are the persisted tokens written by shipped builds —
/// they travel `@AppStorage` and the settings application context, so they are
/// storage keys and must never move or be localized.
///
/// `multiple` is **Vários** in the product's vocabulary: the watch asks which
/// sport before each Match instead of being told once. English case name,
/// Portuguese product name in the documentation — the same convention the
/// Cartão de Resultado types follow.
enum SportSetting: String, CaseIterable, Sendable {
    case beachTennis
    case tennis
    case multiple

    /// What an install lands on before anything is chosen, and what an
    /// unrecognized token decodes to.
    static let `default`: SportSetting = .beachTennis

    /// Decodes a persisted token, falling back to the default for anything
    /// unrecognized — an empty string on a fresh install, a garbled sync, or a
    /// token written by a newer build. Never crashes, never leaves the watch
    /// with no setting at all.
    static func stored(_ rawValue: String) -> SportSetting {
        SportSetting(rawValue: rawValue) ?? .default
    }

    /// The Match type the watch starts directly at a new Match, or `nil` when
    /// the sport isn't settled in advance — Vários, where the watch asks. This
    /// is the whole of the watch's new-Match routing decision, testable without
    /// driving the watch UI.
    var startingMatchType: MatchType? {
        switch self {
        case .beachTennis: return .beachTennis
        case .tennis:      return .tennis
        case .multiple:    return nil
        }
    }

    /// Whether the watch asks which sport before each Match. The complement of
    /// having a Match type to start with, stated as its own name because that is
    /// what the setting means to a player.
    var asksBeforeEachMatch: Bool { startingMatchType == nil }

    /// The picker label. A plain resolved `String`, matching `MatchType`.
    var displayName: String {
        switch self {
        case .beachTennis: return String(localized: "Beach Tennis")
        case .tennis:      return String(localized: "Tennis")
        case .multiple:    return String(localized: "Multiple")
        }
    }

    /// What the Sport section of iPhone Settings says this choice does.
    var settingsFooter: String {
        switch self {
        case .beachTennis: return String(localized: "The Watch will always start a Beach Tennis match.")
        case .tennis:      return String(localized: "The Watch will always start a Tennis match.")
        case .multiple:    return String(localized: "The Watch will ask which sport before each match.")
        }
    }
}
