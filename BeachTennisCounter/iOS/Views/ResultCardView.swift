import SwiftUI

/// Renders a `ResultCard` as the shareable Cartão de Resultado. Purely a shell
/// around the model — every string and number it draws comes from `card`, so
/// what the card *says* is settled (and tested) before anything is drawn.
struct ResultCardView: View {
    let card: ResultCard
    let teamAColor: Color
    let teamBColor: Color

    /// Square, so the card posts cleanly to Instagram and WhatsApp alike. The
    /// image renderer scales this up; every size below is relative to it.
    static let side: CGFloat = 400

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 0)
            scoreboard
            Spacer(minLength: 0)
            footer
        }
        .padding(28)
        .frame(width: Self.side, height: Self.side)
        .background {
            LinearGradient(
                colors: [Color(white: 0.10), Color(white: 0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(card.sportName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .textCase(.uppercase)
                .kerning(1.5)
            Spacer()
            Text(card.dateText)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var scoreboard: some View {
        VStack(spacing: 14) {
            teamRow(name: card.teamAName, score: card.scoreA, color: teamAColor, isWinner: card.winner == .a)

            Text(card.scoreUnitLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .textCase(.uppercase)
                .kerning(1.5)

            teamRow(name: card.teamBName, score: card.scoreB, color: teamBColor, isWinner: card.winner == .b)

            if let breakdown = card.setBreakdown {
                Text(breakdown)
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 2)
            }
        }
    }

    /// The winner is the point of the post: it keeps the team colour, full
    /// white text and a trophy; the loser recedes.
    private func teamRow(name: String, score: Int, color: Color, isWinner: Bool) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isWinner ? color : color.opacity(0.35))
                .frame(width: 14, height: 14)

            // Plain String, not a literal — a user-entered Team Name must never
            // go through String Catalog lookup.
            Text(name)
                .font(.system(size: 24, weight: isWinner ? .bold : .regular))
                .foregroundStyle(.white.opacity(isWinner ? 1 : 0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if isWinner {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(color)
            }

            Spacer(minLength: 8)

            Text("\(score)")
                .font(.system(size: 52, weight: .heavy).monospacedDigit())
                .foregroundStyle(.white.opacity(isWinner ? 1 : 0.55))
        }
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(card.durationText, systemImage: "clock")
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            if let watermark = card.watermark {
                // Small but legible on purpose: every shared card advertises
                // the app. Not localized — it is the app's name.
                Text(watermark)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }
}

extension ResultCardView {
    /// The card as a shareable image, `nil` if rendering fails. `scale` lifts
    /// the 400 pt card to a social-sized bitmap.
    @MainActor
    func rendered(scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

#Preview {
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
        teamBColor: Color(hex: WatchSettings.defaultTeamBColorHex)
    )
}
