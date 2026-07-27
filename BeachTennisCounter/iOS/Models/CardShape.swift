import CoreGraphics

/// The shape the Cartão de Resultado is shared in. Both shapes render the very
/// same ticket (see `ResultCardView`); only the canvas around it changes — the
/// square (1:1) drops cleanly into a feed or a WhatsApp message, the Stories
/// (9:16) fills an Instagram Story or a WhatsApp status instead of floating in
/// a letterbox.
///
/// Pure and `Sendable`: the shape owns its geometry and its persistence rules,
/// so the choice's logic is settled here and tested without rendering anything.
/// The `String` raw value is the persisted token — never localized, it is a
/// storage key, not display copy.
enum CardShape: String, CaseIterable, Sendable, Identifiable {
    case square
    case stories

    var id: String { rawValue }

    /// The shape a player lands on before they have ever chosen. Square is the
    /// universally safe one: it embeds anywhere — a feed, a message, even a
    /// Story (letterboxed but whole) — while a 9:16 image dropped into a square
    /// feed is cropped to ruin. A Stories-first player flips it once and the
    /// choice is then remembered.
    static let `default`: CardShape = .square

    /// Decodes a persisted token back to a shape, falling back to the default
    /// for anything unrecognized — an empty string on first launch, or a value
    /// written by a newer build. A stored shape is never allowed to crash or to
    /// leave the share flow with no shape at all.
    static func stored(_ rawValue: String) -> CardShape {
        CardShape(rawValue: rawValue) ?? .default
    }

    /// The canvas the ticket is mounted on, in points; the image renderer scales
    /// it up to a social-sized bitmap. Square posts cleanly to a feed; the
    /// Stories canvas is a true 9:16 (630 × 1120) so it fills the screen edge to
    /// edge with no letterbox.
    var canvasSize: CGSize {
        switch self {
        case .square:  return CGSize(width: 560, height: 560)
        case .stories: return CGSize(width: 630, height: 1120)
        }
    }

    var aspectRatio: CGFloat { canvasSize.width / canvasSize.height }

    /// The rendered width of the ticket on this canvas. The ticket keeps real
    /// ticket proportions (`ticketAspectRatio`) in both shapes; only its size
    /// changes, so the Stories card reads as the same object scaled up — sitting
    /// deliberately across the wide canvas rather than stranded small in it —
    /// with the sport-tinted backdrop doing the work of the extra height.
    var ticketWidth: CGFloat {
        switch self {
        case .square:  return 460
        case .stories: return 560
        }
    }

    var ticketHeight: CGFloat { ticketWidth / Self.ticketAspectRatio }

    /// Real ticket proportions (2.3:1) — the shape is what reads as a stub torn
    /// off at the end of the match rather than as a screenshot of a scoreboard.
    static let ticketAspectRatio: CGFloat = 2.3
}
