import Foundation

/// Everything the Cartão de Resultado displays, derived from one stored match
/// plus a watermark flag. Pure and `Sendable`: the SwiftUI card, the image
/// renderer, and the share sheet are a thin shell around this value, so the
/// card's content is testable without rendering anything.
struct ResultCard: Sendable, Equatable {
    /// Names the app on every free card — the watermark is the growth loop, not
    /// a defect. Not localized: it is the app's name, the same in every locale.
    static let appWatermark = "Beach Tennis Score"

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
    let winner: Team?
    /// The winning side's Team Name, `nil` when no known side won.
    let winnerName: String?
    let sportName: String
    let dateText: String
    let durationText: String
    /// `nil` on a watermark-free card.
    let watermark: String?

    init(match: StoredMatch, showsWatermark: Bool = true) {
        teamAName = match.teamName(for: .a)
        teamBName = match.teamName(for: .b)

        let sets = match.matchType == .tennis ? match.setHistory : []
        let hasSetsWon = match.setsWonA > 0 || match.setsWonB > 0
        if match.matchType == .tennis && hasSetsWon {
            scoreA = match.setsWonA
            scoreB = match.setsWonB
            scoreUnitLabel = String(localized: "Sets")
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
        winnerName = match.winnerTeam.map { match.teamName(for: $0) }
        sportName = match.matchType.displayName
        dateText = match.date.formatted(date: .abbreviated, time: .shortened)
        durationText = match.durationDisplay
        watermark = showsWatermark ? Self.appWatermark : nil
    }
}
