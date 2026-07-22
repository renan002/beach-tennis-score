import SwiftUI
import UniformTypeIdentifiers

extension MatchType {
    /// The sport's own colour — the ball you actually play with. The accent
    /// belongs to the sport, not to the winning team: two teams swap colours
    /// from match to match, so a team-tinted card has no constant identity,
    /// while every tennis card being optic yellow gives the shared image one.
    /// Team colours keep their own job on the card — they mark the team dots.
    var cardAccent: Color {
        switch self {
        // Same hex path the team colours travel — see `Color(hex:)`.
        case .tennis: return Color(hex: "CCFF00")
        case .beachTennis: return Color(hex: "F08A30")
        }
    }

    /// Near-black on optic yellow, white on the darker beach orange — the stub
    /// carries the score at 46 pt and has to stay legible whichever ball the
    /// sport plays with.
    var cardInkOnAccent: Color {
        var white: CGFloat = 0
        UIColor(cardAccent).getWhite(&white, alpha: nil)
        return white > 0.6 ? Color(white: 0.06) : .white
    }
}

/// Renders a `ResultCard` as the shareable Cartão de Resultado: a match ticket,
/// mounted centred on a square canvas. The body on the left carries the sport,
/// the date and the two teams; a perforated tear line runs down the card; the
/// tear-off stub on the right carries the score over the watermark.
///
/// Purely a shell around the model — every string and number it draws comes
/// from `card`, so what the card *says* is settled (and tested) before anything
/// is drawn. Only how it *looks* lives here.
struct ResultCardView: View {
    let card: ResultCard
    let teamAColor: Color
    let teamBColor: Color
    /// Chooses the accent. The card model describes one match's numbers; the
    /// sport is what the palette hangs off, so the view takes it directly.
    let sport: MatchType

    /// Square, so the card posts cleanly to Instagram and WhatsApp alike. The
    /// image renderer scales this up; every size below is relative to it.
    static let side: CGFloat = 560
    /// Real ticket proportions (2.3:1) — the shape is what reads as a stub torn
    /// off at the end of the match rather than as a screenshot of a scoreboard.
    static let ticketWidth: CGFloat = 460
    static let ticketHeight: CGFloat = 200

    /// The ticket stock. Near-black rather than black so the canvas behind it
    /// still reads as a separate surface under the drop shadow.
    private let paper = Color(white: 0.09)

    var body: some View {
        ticket
            .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
            .frame(width: Self.side, height: Self.side)
            .background {
                LinearGradient(
                    colors: [sport.cardAccent.opacity(0.28), Color(white: 0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .environment(\.colorScheme, .dark)
    }

    private var ticket: some View {
        HStack(spacing: 0) {
            ticketBody
            perforation
            stub
        }
        .frame(width: Self.ticketWidth, height: Self.ticketHeight)
        .background(paper)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var ticketBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 0)
            teamLine(card.teamAName, teamAColor, card.winner == .a)
            teamLine(card.teamBName, teamBColor, card.winner == .b)
                .padding(.top, 6)
            Spacer(minLength: 0)
            footerRail
        }
        .padding(18)
    }

    private var header: some View {
        HStack {
            Text(card.sportName.uppercased())
                .font(.system(size: 11, weight: .black))
                .kerning(2.5)
                .foregroundStyle(sport.cardAccent)
            Spacer()
            Text(card.dateText)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    /// The winner is the point of the post: heavy weight, full white, and a
    /// trophy in the team's own colour; the loser recedes.
    private func teamLine(_ name: String, _ color: Color, _ isWinner: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isWinner ? color : color.opacity(0.3))
                .frame(width: 8, height: 8)

            // Plain String, not a literal — a user-entered Team Name must never
            // go through String Catalog lookup.
            Text(name)
                .font(.system(size: 21, weight: isWinner ? .heavy : .regular))
                .foregroundStyle(.white.opacity(isWinner ? 1 : 0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if isWinner {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(color)
            }
        }
    }

    /// The set-by-set games as chips, with the duration closing the rail. A
    /// beach card has no set breakdown, so it gets no label and no chips —
    /// an empty rail under a heading would read as missing data.
    private var footerRail: some View {
        HStack(spacing: 6) {
            if !setChips.isEmpty {
                Text(card.scoreUnitLabel.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(.white.opacity(0.35))

                ForEach(Array(setChips.enumerated()), id: \.offset) { _, set in
                    Text(set)
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.1)))
                }
            }
            Spacer(minLength: 0)
            Text(card.durationText)
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    /// The model hands the breakdown over as one pre-joined string; splitting
    /// on whitespace rather than on the exact separator keeps the view from
    /// depending on how wide that join happens to be.
    private var setChips: [String] {
        guard let breakdown = card.setBreakdown else { return [] }
        return breakdown.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// Dashed tear line with a notch punched top and bottom.
    private var perforation: some View {
        ZStack {
            VStack(spacing: 5) {
                ForEach(0..<12, id: \.self) { _ in
                    Rectangle()
                        .fill(.white.opacity(0.25))
                        .frame(width: 1, height: 6)
                }
            }
            VStack {
                notch.offset(y: -7)
                Spacer()
                notch.offset(y: 7)
            }
        }
        .frame(width: 18)
    }

    /// Reads as punched out of the ticket: the canvas colour, not the stock's.
    private var notch: some View {
        Circle()
            .fill(Color(white: 0.02))
            .frame(width: 14, height: 14)
    }

    private var stub: some View {
        ZStack {
            sport.cardAccent
            VStack(spacing: 2) {
                Spacer(minLength: 0)
                Text("\(card.scoreA)")
                    .font(.system(size: 46, weight: .black).monospacedDigit())
                Rectangle()
                    .fill(sport.cardInkOnAccent.opacity(0.5))
                    .frame(width: 26, height: 2)
                Text("\(card.scoreB)")
                    .font(.system(size: 46, weight: .black).monospacedDigit())
                Spacer(minLength: 0)
                if let watermark = card.watermark {
                    // Small but legible on purpose: every shared card
                    // advertises the app. Not localized — it is the app's name.
                    Text(watermark.uppercased())
                        .font(.system(size: 8, weight: .black))
                        .kerning(1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .foregroundStyle(sport.cardInkOnAccent)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
        .frame(width: 118)
    }
}

extension ResultCardView {
    /// The card as an image, `nil` if rendering fails. `scale` lifts the 560 pt
    /// canvas to a social-sized bitmap.
    @MainActor
    func rendered(scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// The card as the share sheet takes it. Rendering happens inside the export,
/// so opening a match costs nothing and the share action is always offered —
/// only the sharing player pays for the bitmap.
struct ShareableResultCard: Transferable, Sendable {
    let card: ResultCard
    let teamAColor: Color
    let teamBColor: Color
    let sport: MatchType

    struct RenderFailure: Error {}

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { shareable in
            try await shareable.pngData()
        }
        // Not localized: a file name, not display copy.
        .suggestedFileName("beach-tennis-score.png")
    }

    @MainActor
    private func pngData() throws -> Data {
        let view = ResultCardView(
            card: card,
            teamAColor: teamAColor,
            teamBColor: teamBColor,
            sport: sport
        )
        guard let data = view.rendered()?.pngData() else { throw RenderFailure() }
        return data
    }
}

#Preview("Beach") {
    ResultCardView(
        card: ResultCard(match: StoredMatch(
            date: Date(),
            setScoreA: 6,
            setScoreB: 4,
            winner: "a",
            duration: 2_730,
            teamAName: "Renan & Léo",
            teamBName: "Visitors"
        )),
        teamAColor: Color(hex: WatchSettings.defaultTeamAColorHex),
        teamBColor: Color(hex: WatchSettings.defaultTeamBColorHex),
        sport: .beachTennis
    )
}

#Preview("Tennis") {
    ResultCardView(
        card: ResultCard(match: StoredMatch(
            date: Date(),
            setScoreA: 0,
            setScoreB: 0,
            setsWonA: 1,
            setsWonB: 2,
            winner: "b",
            duration: 4_500,
            setHistoryData: (try? JSONEncoder().encode([
                SetRecord(setNumber: 1, gamesA: 6, gamesB: 4, winner: .a, isTiebreak: false),
                SetRecord(setNumber: 2, gamesA: 3, gamesB: 6, winner: .b, isTiebreak: false),
                SetRecord(setNumber: 3, gamesA: 8, gamesB: 10, winner: .b, isTiebreak: true)
            ])) ?? Data(),
            matchTypeRaw: MatchType.tennis.rawValue,
            teamAName: "Renan",
            teamBName: "Marina & Caio"
        )),
        teamAColor: Color(hex: WatchSettings.defaultTeamAColorHex),
        teamBColor: Color(hex: WatchSettings.defaultTeamBColorHex),
        sport: .tennis
    )
}
