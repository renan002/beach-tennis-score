import Foundation

/// Everything the Cartão de Resultado displays, derived from one stored match
/// plus a watermark flag. Pure and `Sendable`: the SwiftUI card, the image
/// renderer, and the share sheet are a thin shell around this value, so the
/// card's content is testable without rendering anything.
struct ResultCard: Sendable, Equatable {
    /// Names the app on every free card — the watermark is the growth loop, not
    /// a defect. Not localized: it is the app's name, the same in every locale.
    static let appWatermark = "Beach Tennis Score"

    /// Where the watermark points. A constant, never fetched: sharing works in
    /// airplane mode exactly as it did before the link existed. Locale-free
    /// (`/app/`, not `/br/app/`) so the App Store redirects each viewer to
    /// their own storefront.
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6765569699")!

    /// The share-sheet message that travels beside the card image. WhatsApp,
    /// Messages and Mail carry it as text next to the photo; Instagram-style
    /// targets take the image alone and ignore it, which is exactly the old
    /// behaviour. The sentence is localized, the URL never is.
    static var shareMessage: String {
        "\(String(localized: "Scored with Beach Tennis Score")) \(appStoreURL.absoluteString)"
    }

    let teamAName: String
    let teamBName: String
    /// The headline numbers, in the unit named by `scoreUnitLabel`.
    let scoreA: Int
    let scoreB: Int
    /// What the headline numbers count — "Sets" for beach tennis (the beach
    /// convention labels games as sets in every language) and for a tennis
    /// match with sets on the board, "Games" for a tennis match abandoned
    /// inside its first set.
    let scoreUnitLabel: String
    /// Tennis only: the games in each completed set, "6-4  3-6  10-8". `nil`
    /// when there is no set to break down.
    let setBreakdown: String?
    /// The side to highlight, `nil` when no known side won.
    let winner: Team?
    let sportName: String
    let dateText: String
    let durationText: String
    /// `nil` on a watermark-free card.
    let watermark: String?

    init(match: StoredMatch, showsWatermark: Bool = true) {
        teamAName = match.teamName(for: .a)
        teamBName = match.teamName(for: .b)

        if match.isSetScored {
            let sets = match.setHistory
            scoreA = match.setsWonA
            scoreB = match.setsWonB
            scoreUnitLabel = MatchType.setsSectionTitle
            setBreakdown = sets.isEmpty
                ? nil
                : sets.map { "\($0.gamesA)-\($0.gamesB)" }.joined(separator: "  ")
        } else {
            scoreA = match.setScoreA
            scoreB = match.setScoreB
            scoreUnitLabel = match.matchType.gamesSectionTitle
            setBreakdown = nil
        }

        winner = match.winnerTeam
        sportName = match.matchType.displayName
        dateText = match.date.formatted(date: .abbreviated, time: .shortened)
        // Hours and minutes, localized by the system — the history screen's
        // "75:20" is fine next to a "Duration" label but reads as a score on a
        // card shared with no label at all.
        durationText = Duration.seconds(match.duration)
            .formatted(.units(allowed: [.hours, .minutes], width: .narrow))
        watermark = showsWatermark ? Self.appWatermark : nil
    }
}
