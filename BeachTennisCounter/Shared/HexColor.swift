import Foundation

/// The one place a hex colour string is parsed.
///
/// Lives in `Shared/` with no SwiftUI import, so both targets can take it and
/// the test bundle can reach it through the iOS app — which is the point: the
/// watch's decode used to be a second copy of these six lines, sitting in the
/// one layer no test can reach. Both
/// `Color(hex:)` initializers are thin wrappers over this and keep their own
/// failure conventions: the watch's stays failable because it decodes colours
/// synced from the phone, which can arrive garbled; the phone's stays
/// non-failable because it decodes its own literals and its own stored values.
enum HexColor {

    /// A decoded colour's channels, each in `0...1`.
    struct Components: Equatable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
    }

    /// Parses `RRGGBB`, tolerating surrounding whitespace and a leading `#`.
    /// Anything else — wrong length, shorthand, non-hex characters — is `nil`.
    static func components(_ hex: String) -> Components? {
        var digits = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6, let value = UInt64(digits, radix: 16) else { return nil }
        return Components(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
