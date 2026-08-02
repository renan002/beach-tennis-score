import Foundation

/// The Team Name rules, in one place: what a raw name resolves to on screen, how
/// long a name may be, and the form a typed name is stored in.
///
/// A namespace of pure functions rather than a type: the names themselves stay
/// exactly where they are — a SwiftData attribute on the stored match, a codable
/// field on the Match state and on the wire payload — so this carries no
/// migration risk. `MatchState.teamName(for:)` and `StoredMatch.teamName(for:)`
/// keep their signatures and forward here, which is why the rule can be stated
/// once without moving a single call site.
enum TeamName {
    /// Name length cap: keeps the watch serve buttons and history lines from
    /// truncating. Counts grapheme clusters (`String.prefix`), so a 12-emoji
    /// name is still 12.
    static let maxLength = 12

    /// The label to show for `team`: its Team Name when set, otherwise the
    /// localized "Team A"/"Team B" fallback. Returns a plain `String` so a
    /// user-entered name never goes through String Catalog lookup — only the
    /// fallback literal is localized.
    static func resolve(_ raw: String, for team: Team) -> String {
        raw.isEmpty ? team.displayName : raw
    }

    /// Hard-caps typed or pasted input at `maxLength`. Applied per keystroke;
    /// trimming happens later, at `committed(_:)`.
    static func capped(_ raw: String) -> String {
        String(raw.prefix(maxLength))
    }

    /// The canonical stored form of a name the user has finished typing:
    /// surrounding whitespace stripped, a whitespace-only name collapsing to
    /// empty — which `resolve(_:for:)` then reads as unnamed. Applied at the
    /// commit points rather than per-keystroke, so the field stays natural to
    /// type in.
    static func committed(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
