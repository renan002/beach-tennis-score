import Foundation

/// The Team Name rules, stated once: how a raw name resolves against its side,
/// how long a name may be, and what its committed form is.
///
/// Pure functions with no UI and no storage. Nothing here changes a stored
/// property — the names remain a plain `String` on the Match state, on the
/// stored match and on the wire payload; this namespace only says what those
/// strings mean.
enum TeamName {
    /// The longest a Team Name may be, in characters. Twelve is what fits the
    /// watch's serve buttons without truncating.
    static let maxLength = 12

    /// The label to show for `team`: its committed name when it has one,
    /// otherwise the localized `Team.displayName` fallback.
    ///
    /// Resolved to a plain `String` so a user-entered name never reaches String
    /// Catalog lookup — only the fallback literal is localized.
    ///
    /// Resolving through `committed` — rather than testing the raw string for
    /// emptiness — is what makes "whitespace-only means unnamed" true at every
    /// display site instead of only where Settings happened to commit the name.
    /// A name arriving over the watch settings channel, or one stored before
    /// trim-on-commit shipped, is never trusted to be canonical already.
    static func resolved(_ raw: String, for team: Team) -> String {
        let name = committed(raw)
        return name.isEmpty ? team.displayName : name
    }

    /// `raw` hard-capped at `maxLength`. `prefix` counts Characters — grapheme
    /// clusters — so a twelve-emoji name is twelve characters and survives whole.
    static func capped(_ raw: String) -> String {
        String(raw.prefix(maxLength))
    }

    /// The canonical stored form of a typed name: surrounding whitespace
    /// stripped, whitespace-only collapsing to empty (which is how "unnamed" is
    /// spelled). Applied at commit points rather than per keystroke, so the name
    /// field stays natural to type in.
    static func committed(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
