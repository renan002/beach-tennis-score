import Foundation

/// The one hex decode in the project, as plain colour components.
///
/// Deliberately not a `Color` extension: the two platforms want two different
/// failure behaviours — the watch decodes synced values that can be garbled and
/// stays failable, the phone decodes its own literals and stored values and
/// falls back to black — so each `Color(hex:)` keeps its own convention and both
/// parse through this. No SwiftUI import, so the parsing is testable.
enum HexColor {
    /// Red, green and blue in `0...1` for a six-digit RGB hex string, or `nil`
    /// when the string is not one. Tolerates a leading `#` and surrounding
    /// whitespace; anything else — wrong length, non-hex characters — fails.
    static func components(_ hex: String) -> (red: Double, green: Double, blue: Double)? {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        return (
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
