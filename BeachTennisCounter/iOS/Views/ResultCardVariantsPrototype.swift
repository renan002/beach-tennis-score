// PROTOTYPE — throwaway. Four structurally different Cartão de Resultado
// designs over the same `ResultCard` data, rendered to PNGs by
// Tests/ResultCardVariantsDumpPrototype.swift so they can be judged as the
// images they will actually be. Only the winner gets folded into
// ResultCardView.swift; the rest lives on the proto/ branch.
//
// A — Placar (shipped): horizontal team rows, score right, dark minimal.
// B — Pôster: score is the hero, teams small above/below, sand-light.
// C — Ingresso: split card, winner's colour blocks the left rail, set chips.
// D — Manchete (4:5): winner as a headline, score secondary, story format.

import SwiftUI

// MARK: - B — Pôster

/// The number is the poster. Everything else is caption. Light "sand" palette
/// so it reads as beach rather than as a sports-app dark theme.
struct ResultCardVariantB: View {
    let card: ResultCard
    let teamAColor: Color
    let teamBColor: Color

    static let side: CGFloat = 400

    var body: some View {
        VStack(spacing: 0) {
            Text(card.sportName.uppercased())
                .font(.system(size: 13, weight: .black))
                .kerning(3)
                .foregroundStyle(Color(red: 0.62, green: 0.44, blue: 0.24))

            Spacer()

            Text(card.teamAName)
                .font(.system(size: 19, weight: card.winner == .a ? .bold : .regular))
                .foregroundStyle(card.winner == .a ? .black : .black.opacity(0.45))
                .lineLimit(1).minimumScaleFactor(0.5)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(card.scoreA)")
                    .foregroundStyle(card.winner == .a ? teamAColor : .black.opacity(0.3))
                Text("–").foregroundStyle(.black.opacity(0.25))
                Text("\(card.scoreB)")
                    .foregroundStyle(card.winner == .b ? teamBColor : .black.opacity(0.3))
            }
            .font(.system(size: 108, weight: .black).monospacedDigit())
            .padding(.vertical, -6)

            Text(card.teamBName)
                .font(.system(size: 19, weight: card.winner == .b ? .bold : .regular))
                .foregroundStyle(card.winner == .b ? .black : .black.opacity(0.45))
                .lineLimit(1).minimumScaleFactor(0.5)

            Text(card.scoreUnitLabel.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(2)
                .foregroundStyle(.black.opacity(0.35))
                .padding(.top, 10)

            if let breakdown = card.setBreakdown {
                Text(breakdown)
                    .font(.system(size: 14, weight: .medium).monospacedDigit())
                    .foregroundStyle(.black.opacity(0.5))
                    .padding(.top, 4)
            }

            Spacer()

            HStack(spacing: 6) {
                Text(card.dateText)
                Text("·")
                Text(card.durationText)
            }
            .font(.system(size: 12))
            .foregroundStyle(.black.opacity(0.45))

            if let watermark = card.watermark {
                Text(watermark)
                    .font(.system(size: 12, weight: .heavy))
                    .kerning(0.5)
                    .foregroundStyle(Color(red: 0.62, green: 0.44, blue: 0.24))
                    .padding(.top, 8)
            }
        }
        .padding(26)
        .frame(width: Self.side, height: Self.side)
        .background(Color(red: 0.98, green: 0.95, blue: 0.89))
        .environment(\.colorScheme, .light)
    }
}

// MARK: - C — Ingresso

/// A match ticket: a colour rail claimed by the winner, a stub footer, and the
/// set-by-set detail promoted to chips instead of a runt line of text.
struct ResultCardVariantC: View {
    let card: ResultCard
    let teamAColor: Color
    let teamBColor: Color

    static let side: CGFloat = 400

    private var winnerColor: Color {
        switch card.winner {
        case .a: return teamAColor
        case .b: return teamBColor
        case nil: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Rail: the sport, set sideways, in the winner's colour.
            ZStack {
                winnerColor
                Text(card.sportName.uppercased())
                    .font(.system(size: 15, weight: .black))
                    .kerning(4)
                    .foregroundStyle(.white)
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
                    // The rotated text keeps its unrotated width for layout;
                    // pin it to the rail so the rail doesn't grow to fit it.
                    .frame(width: 58)
            }
            .frame(width: 58)
            .clipped()

            VStack(alignment: .leading, spacing: 0) {
                Text(card.dateText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                teamLine(card.teamAName, card.scoreA, teamAColor, card.winner == .a)
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(height: 1)
                    .padding(.vertical, 10)
                teamLine(card.teamBName, card.scoreB, teamBColor, card.winner == .b)

                Text(card.scoreUnitLabel.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 8)

                if let breakdown = card.setBreakdown {
                    HStack(spacing: 6) {
                        ForEach(Array(breakdown.split(separator: "  ").enumerated()), id: \.offset) { _, set in
                            Text(String(set))
                                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.white.opacity(0.1)))
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()

                // Stub: torn-ticket dashes, then the small print.
                HStack(spacing: 4) {
                    ForEach(0..<28, id: \.self) { _ in
                        Rectangle().fill(.white.opacity(0.2)).frame(width: 6, height: 1)
                    }
                }
                .padding(.bottom, 10)

                HStack {
                    Text(card.durationText)
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    if let watermark = card.watermark {
                        Text(watermark)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .padding(22)
        }
        .frame(width: Self.side, height: Self.side)
        .background(Color(white: 0.09))
        .environment(\.colorScheme, .dark)
    }

    private func teamLine(_ name: String, _ score: Int, _ color: Color, _ isWinner: Bool) -> some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(isWinner ? color : color.opacity(0.3))
                .frame(width: 4, height: 30)
            Text(name)
                .font(.system(size: 20, weight: isWinner ? .bold : .regular))
                .foregroundStyle(.white.opacity(isWinner ? 1 : 0.5))
                .lineLimit(1).minimumScaleFactor(0.5)
            Spacer(minLength: 6)
            Text("\(score)")
                .font(.system(size: 34, weight: .black).monospacedDigit())
                .foregroundStyle(.white.opacity(isWinner ? 1 : 0.5))
        }
    }
}

// MARK: - C2 — Ingresso, real ticket proportions

/// C, but shaped like an actual ticket (2.3:1) instead of a square: body on the
/// left, perforation with punched notches, tear-off stub on the right carrying
/// the score and the watermark.
///
/// `padded` centres that ticket on a square canvas — a 2.3:1 image posts badly
/// to a square feed, so the two are worth judging side by side.
struct ResultCardVariantC2: View {
    let card: ResultCard
    let teamAColor: Color
    let teamBColor: Color
    /// The sport's own colour — the ball you actually play with. Tennis is
    /// optic yellow #CCFF00; beach keeps the app's orange.
    let sportColor: Color
    var padded = false

    static let ticketWidth: CGFloat = 460
    static let ticketHeight: CGFloat = 200
    static let side: CGFloat = 560

    static let tennisBall = Color(red: 204 / 255, green: 255 / 255, blue: 0)
    static let beachOrange = Color(red: 240 / 255, green: 138 / 255, blue: 48 / 255)

    private let paper = Color(white: 0.09)

    private var winnerColor: Color {
        switch card.winner {
        case .a: return teamAColor
        case .b: return teamBColor
        case nil: return .gray
        }
    }

    /// Black on optic yellow, white on the darker beach orange — the stub has
    /// to stay legible whichever ball the sport plays with.
    private var onSport: Color {
        var white: CGFloat = 0
        UIColor(sportColor).getWhite(&white, alpha: nil)
        return white > 0.6 ? Color(white: 0.06) : .white
    }

    @ViewBuilder
    var body: some View {
        if padded {
            ticket
                .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
                .frame(width: Self.side, height: Self.side)
                .background(
                    LinearGradient(colors: [sportColor.opacity(0.28), Color(white: 0.04)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .environment(\.colorScheme, .dark)
        } else {
            ticket.environment(\.colorScheme, .dark)
        }
    }

    private var ticket: some View {
        HStack(spacing: 0) {
            main
            perforation
            stub
        }
        .frame(width: Self.ticketWidth, height: Self.ticketHeight)
        .background(paper)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(card.sportName.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .kerning(2.5)
                    .foregroundStyle(sportColor)
                Spacer()
                Text(card.dateText)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            teamLine(card.teamAName, teamAColor, card.winner == .a)
            teamLine(card.teamBName, teamBColor, card.winner == .b)
                .padding(.top, 6)

            Spacer()

            HStack(spacing: 6) {
                Text(card.scoreUnitLabel.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(.white.opacity(0.35))
                if let breakdown = card.setBreakdown {
                    ForEach(Array(breakdown.split(separator: "  ").enumerated()), id: \.offset) { _, set in
                        Text(String(set))
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.white.opacity(0.1)))
                    }
                }
                Spacer()
                Text(card.durationText)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(18)
    }

    private func teamLine(_ name: String, _ color: Color, _ isWinner: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isWinner ? color : color.opacity(0.3))
                .frame(width: 8, height: 8)
            Text(name)
                .font(.system(size: 21, weight: isWinner ? .heavy : .regular))
                .foregroundStyle(.white.opacity(isWinner ? 1 : 0.5))
                .lineLimit(1).minimumScaleFactor(0.5)
            if isWinner {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(color)
            }
        }
    }

    /// Dashed tear line with a notch punched top and bottom.
    private var perforation: some View {
        ZStack {
            VStack(spacing: 5) {
                ForEach(0..<12, id: \.self) { _ in
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 6)
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

    /// Punched out of the ticket, so whatever is behind the card shows through.
    private var notch: some View {
        Circle()
            .fill(Color(white: 0.02))
            .frame(width: 14, height: 14)
    }

    private var stub: some View {
        ZStack {
            sportColor
            VStack(spacing: 2) {
                Spacer()
                Text("\(card.scoreA)")
                    .font(.system(size: 46, weight: .black).monospacedDigit())
                Rectangle().fill(onSport.opacity(0.5)).frame(width: 26, height: 2)
                Text("\(card.scoreB)")
                    .font(.system(size: 46, weight: .black).monospacedDigit())
                Spacer()
                if let watermark = card.watermark {
                    Text(watermark.uppercased())
                        .font(.system(size: 8, weight: .black))
                        .kerning(1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .foregroundStyle(onSport)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
        .frame(width: 118)
    }
}

// MARK: - D — Manchete

/// Story-shaped (4:5). The post's message is "X won" as a headline; the score
/// is the evidence underneath, not the hero.
struct ResultCardVariantD: View {
    let card: ResultCard
    let teamAColor: Color
    let teamBColor: Color

    static let width: CGFloat = 400
    static let height: CGFloat = 500

    private var winnerColor: Color {
        switch card.winner {
        case .a: return teamAColor
        case .b: return teamBColor
        case nil: return .white
        }
    }

    private var winnerName: String? {
        switch card.winner {
        case .a: return card.teamAName
        case .b: return card.teamBName
        case nil: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(card.sportName.uppercased())  ·  \(card.dateText)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            Spacer()

            if let winnerName {
                // Reuses the existing "%@ wins" key — pt-BR "%@ venceu".
                Text(String(format: String(localized: "%@ wins"), winnerName))
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.4)
            }

            Rectangle()
                .fill(winnerColor)
                .frame(width: 64, height: 5)
                .padding(.vertical, 22)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(card.teamAName)
                    .font(.system(size: 15, weight: card.winner == .a ? .bold : .regular))
                Text("\(card.scoreA) – \(card.scoreB)")
                    .font(.system(size: 22, weight: .black).monospacedDigit())
                Text(card.teamBName)
                    .font(.system(size: 15, weight: card.winner == .b ? .bold : .regular))
            }
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            HStack(spacing: 8) {
                Text(card.scoreUnitLabel.uppercased())
                if let breakdown = card.setBreakdown {
                    Text("·")
                    Text(breakdown).monospacedDigit()
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
            .padding(.top, 6)

            Spacer()

            HStack {
                Text(card.durationText)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if let watermark = card.watermark {
                    Text(watermark)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(30)
        .frame(width: Self.width, height: Self.height, alignment: .leading)
        .background {
            LinearGradient(
                colors: [winnerColor.opacity(0.35), Color(white: 0.06)],
                startPoint: .topTrailing,
                endPoint: .bottom
            )
            .background(Color(white: 0.06))
        }
        .environment(\.colorScheme, .dark)
    }
}
