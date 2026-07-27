import Foundation

/// Estatísticas: everything the on-device stats screen shows, computed from a
/// collection of stored matches. Pure and `Sendable` — the SwiftUI screen is a
/// thin shell around this value, so the numbers are testable without a view or
/// a SwiftData container. Nothing here is persisted; the value is recomputed
/// from the live Match History on demand.
///
/// The player is **Team A** — the scoring UI's established default. Every
/// win, loss, streak and record is from Team A's point of view; the stats
/// screen states the convention.
struct MatchStatistics: Sendable, Equatable {
    let matchesPlayed: Int
    /// Matches Team A won, and matches Team A lost. A stored match that names
    /// neither side (corrupt `winner`) counts as neither.
    let wins: Int
    let losses: Int
    /// Wins ÷ matches played, in `0...1`. Zero when nothing has been played.
    let winRate: Double
    /// Consecutive Team A wins ending at the most recent match; zero when the
    /// latest match was not a win.
    let currentStreak: Int
    /// Longest run of consecutive Team A wins anywhere in the history.
    let bestStreak: Int
    /// Golden-point games (beach tennis sudden death) Team A won and lost,
    /// counted from the Game Log.
    let goldenPointsWon: Int
    let goldenPointsLost: Int
    /// Super-tiebreak games Team A won and lost — the beach tennis decider at
    /// 6-6. Tennis set tiebreaks also carry `isTiebreak` but are a different
    /// thing, so they are not counted here.
    let superTiebreaksWon: Int
    let superTiebreaksLost: Int
    /// Per-sport split of `matchesPlayed`.
    let beachMatches: Int
    let tennisMatches: Int
    /// Court time across every match, and the per-match average. Average is
    /// zero when nothing has been played.
    let totalDuration: TimeInterval
    let averageDuration: TimeInterval

    /// No matches yet — the screen shows an empty state, not zeros dressed up
    /// as insight.
    var isEmpty: Bool { matchesPlayed == 0 }

    init(matches: [StoredMatch]) {
        let played = matches.count
        matchesPlayed = played

        let winners = matches.map(\.winnerTeam)
        let winCount = winners.lazy.filter { $0 == .a }.count
        wins = winCount
        losses = winners.lazy.filter { $0 == .b }.count
        winRate = played == 0 ? 0 : Double(winCount) / Double(played)

        // Streaks read the history in chronological order, whatever order the
        // caller handed the matches in.
        let chronological = matches.sorted { $0.date < $1.date }
        var best = 0
        var run = 0
        for match in chronological {
            if match.winnerTeam == .a {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        bestStreak = best
        // `run` is the streak still alive at the latest match — the current
        // streak, already zero if that match was not a Team A win.
        currentStreak = run

        // Golden points and super-tiebreaks are derived from the Game Log: a
        // golden-point game carries the "GP" score display, the super-tiebreak
        // the `isTiebreak` flag. Both are beach tennis concepts — a tennis set
        // tiebreak also sets `isTiebreak`, so super-tiebreaks are counted only
        // for beach matches, keeping the "super" record what the spec means.
        var gpWon = 0, gpLost = 0, tbWon = 0, tbLost = 0
        for match in matches {
            let isBeach = match.matchType == .beachTennis
            for game in match.gameHistory {
                if game.gameScoreDisplay == GameRecord.goldenPointDisplay {
                    if game.winner == .a { gpWon += 1 } else { gpLost += 1 }
                }
                if isBeach && game.isTiebreak {
                    if game.winner == .a { tbWon += 1 } else { tbLost += 1 }
                }
            }
        }
        goldenPointsWon = gpWon
        goldenPointsLost = gpLost
        superTiebreaksWon = tbWon
        superTiebreaksLost = tbLost

        beachMatches = matches.lazy.filter { $0.matchType == .beachTennis }.count
        tennisMatches = matches.lazy.filter { $0.matchType == .tennis }.count

        let total = matches.reduce(0) { $0 + $1.duration }
        totalDuration = total
        averageDuration = played == 0 ? 0 : total / Double(played)
    }
}
