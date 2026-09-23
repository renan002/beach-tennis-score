import Foundation

/// The single pair of numbers that stands for a match's result — the same
/// projection for the live Placar, the Match List and the Cartão de Resultado
/// (CONTEXT.md "Headline Score"). Always derived from the match's own state or
/// stored rows; never a field persisted for its own sake.
///
/// Centralized here so the watch's live overlay and the iPhone's stored
/// displays share one rule and cannot drift: every home answers "what is this
/// match's headline?" the same way.
struct HeadlineScore: Equatable, Sendable {
    enum Unit: String, Sendable {
        /// Tennis's real sets. The only unit that carries a per-set breakdown.
        case sets
        /// Beach tennis games (labelled "Sets" in every language), tennis games
        /// inside a set, and ping pong games once a best-of-N match has a
        /// completed game on the board.
        case games
        /// Ping pong best-of-1, or any ping match abandoned in its first game.
        case points
    }

    let a: Int
    let b: Int
    let unit: Unit

    /// The number for one side, so display sites can read either column off the
    /// same value.
    func number(for team: Team) -> Int {
        team == .a ? a : b
    }

    /// The ping pong projection in all three display homes.
    ///
    /// A best-of-N match with a completed game on the board shows games won;
    /// every other ping match — best-of-1, or any match abandoned in its first
    /// game — shows points. `pointsA/B` are the caller's best-known points: a
    /// finished match's terminal pair (which the Game Log records, ADR 0005),
    /// or the live integer points in `PingPongState`. A finished best-of-1
    /// keeps its terminal numeric points rather than a bare games-won line.
    static func pingPong(
        gamesWonA: Int,
        gamesWonB: Int,
        pointsA: Int,
        pointsB: Int,
        bestOf: Int
    ) -> HeadlineScore {
        if bestOf > 1, gamesWonA + gamesWonB > 0 {
            return HeadlineScore(a: gamesWonA, b: gamesWonB, unit: .games)
        }
        return HeadlineScore(a: pointsA, b: pointsB, unit: .points)
    }

    /// The live projection, straight off the Match being scored.
    ///
    /// Ping pong reads only `PingPongState` — the sport's own counters, never
    /// the legacy beach/tennis fields (ADR 0005). On the terminal point the
    /// ScoreEngine leaves the final points in `PingPongState`, so the live
    /// state already holds a finished best-of-1's headline pair.
    static func live(_ state: MatchState) -> HeadlineScore {
        switch state.matchType {
        case .beachTennis:
            return HeadlineScore(a: state.setScoreA, b: state.setScoreB, unit: .games)
        case .tennis:
            if state.setsWonA > 0 || state.setsWonB > 0 {
                return HeadlineScore(a: state.setsWonA, b: state.setsWonB, unit: .sets)
            }
            return HeadlineScore(a: state.setScoreA, b: state.setScoreB, unit: .games)
        case .pingPong:
            return pingPong(
                gamesWonA: state.pingGamesWon(for: .a),
                gamesWonB: state.pingGamesWon(for: .b),
                pointsA: state.pingPoints(for: .a),
                pointsB: state.pingPoints(for: .b),
                bestOf: state.ruleset.pingPong?.bestOf ?? 1
            )
        }
    }

    /// The projection over a stored match's persisted rows. The flat
    /// `setScoreA/B` columns carry ping pong's games-won (ADR 0005); the
    /// optional numeric-points fields carry the terminal points for the
    /// best-of-1 / first-game fallback. A legacy row predating the numeric
    /// fields falls back to the terminal game's Game Log record, then to the
    /// flat columns — the old 0-0 first-game floor is only reached when neither
    /// exists.
    static func stored(
        matchType: MatchType,
        setScoreA: Int,
        setScoreB: Int,
        setsWonA: Int,
        setsWonB: Int,
        bestOf: Int?,
        hasSets: Bool,
        gameHistory: [GameRecord],
        pingPointsA: Int? = nil,
        pingPointsB: Int? = nil
    ) -> HeadlineScore {
        switch matchType {
        case .beachTennis:
            return HeadlineScore(a: setScoreA, b: setScoreB, unit: .games)
        case .tennis:
            if hasSets, setsWonA + setsWonB > 0 {
                return HeadlineScore(a: setsWonA, b: setsWonB, unit: .sets)
            }
            return HeadlineScore(a: setScoreA, b: setScoreB, unit: .games)
        case .pingPong:
            let last = gameHistory.last
            let pointsA = pingPointsA ?? last?.pointsA ?? setScoreA
            let pointsB = pingPointsB ?? last?.pointsB ?? setScoreB
            return pingPong(
                gamesWonA: setScoreA,
                gamesWonB: setScoreB,
                pointsA: pointsA,
                pointsB: pointsB,
                bestOf: bestOf ?? 1
            )
        }
    }
}