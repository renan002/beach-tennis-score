import XCTest
@testable import BeachTennisCounter

/// The Estatísticas seam: a collection of stored matches in, the computed stats
/// value out. Pure input → output over the Match History, in the spirit of the
/// score-engine suites. No view, no SwiftData container.
final class MatchStatisticsTests: XCTestCase {

    private func gameHistoryData(_ records: [GameRecord]) -> Data {
        (try? JSONEncoder().encode(records)) ?? Data()
    }

    /// A finished match. `winner` is "a" (Team A, the player) by default; pass
    /// "b" for a loss. `daysAgo` orders matches in time — larger is older.
    private func makeMatch(
        winner: String = "a",
        daysAgo: Double = 0,
        duration: TimeInterval = 1_800,
        matchTypeRaw: String = "beachTennis",
        gameHistory: [GameRecord] = []
    ) -> StoredMatch {
        StoredMatch(
            date: Date(timeIntervalSince1970: 1_700_000_000 - daysAgo * 86_400),
            setScoreA: 6,
            setScoreB: 3,
            winner: winner,
            duration: duration,
            gameHistoryData: gameHistoryData(gameHistory),
            matchTypeRaw: matchTypeRaw
        )
    }

    private func goldenPointGame(winner: Team) -> GameRecord {
        GameRecord(gameNumber: 1, setScoreA: 1, setScoreB: 0, winner: winner,
                   isTiebreak: false, gameScoreDisplay: GameRecord.goldenPointDisplay)
    }

    private func tiebreakGame(winner: Team) -> GameRecord {
        GameRecord(gameNumber: 13, setScoreA: 7, setScoreB: 6, winner: winner,
                   isTiebreak: true, gameScoreDisplay: "7–5")
    }

    private func plainGame(winner: Team) -> GameRecord {
        GameRecord(gameNumber: 1, setScoreA: 1, setScoreB: 0, winner: winner,
                   isTiebreak: false, gameScoreDisplay: "40–15")
    }

    // MARK: - Empty history

    func test_empty_isEmptyAndAllZero() {
        let stats = MatchStatistics(matches: [])

        XCTAssertTrue(stats.isEmpty)
        XCTAssertEqual(stats.matchesPlayed, 0)
        XCTAssertEqual(stats.wins, 0)
        XCTAssertEqual(stats.losses, 0)
        XCTAssertEqual(stats.winRate, 0)
        XCTAssertEqual(stats.currentStreak, 0)
        XCTAssertEqual(stats.bestStreak, 0)
        XCTAssertEqual(stats.totalDuration, 0)
        XCTAssertEqual(stats.averageDuration, 0)
    }

    // MARK: - Totals & win rate

    func test_totals_countMatchesWinsLosses() {
        let stats = MatchStatistics(matches: [
            makeMatch(winner: "a"),
            makeMatch(winner: "b"),
            makeMatch(winner: "a"),
        ])

        XCTAssertFalse(stats.isEmpty)
        XCTAssertEqual(stats.matchesPlayed, 3)
        XCTAssertEqual(stats.wins, 2)
        XCTAssertEqual(stats.losses, 1)
        XCTAssertEqual(stats.winRate, 2.0 / 3.0, accuracy: 1e-9)
    }

    /// A win rate of a single won match is 1.0, not a rounded fraction.
    func test_winRate_singleWin_isOne() {
        XCTAssertEqual(MatchStatistics(matches: [makeMatch(winner: "a")]).winRate, 1.0)
    }

    /// A corrupt winner names neither side — it counts toward matches played
    /// but is neither a win nor a loss, and it drags the win rate down.
    func test_unrecognizedWinner_countsAsPlayedNotWonOrLost() {
        let stats = MatchStatistics(matches: [
            makeMatch(winner: "a"),
            makeMatch(winner: ""),
        ])

        XCTAssertEqual(stats.matchesPlayed, 2)
        XCTAssertEqual(stats.wins, 1)
        XCTAssertEqual(stats.losses, 0)
        XCTAssertEqual(stats.winRate, 0.5)
    }

    // MARK: - Streaks

    func test_streaks_singleWin() {
        let stats = MatchStatistics(matches: [makeMatch(winner: "a")])

        XCTAssertEqual(stats.currentStreak, 1)
        XCTAssertEqual(stats.bestStreak, 1)
    }

    func test_streaks_singleLoss_isZero() {
        let stats = MatchStatistics(matches: [makeMatch(winner: "b")])

        XCTAssertEqual(stats.currentStreak, 0)
        XCTAssertEqual(stats.bestStreak, 0)
    }

    /// Order handed in should not matter: the calculator sorts by date. Newest
    /// match (daysAgo 0) is a loss, so the current streak is broken while the
    /// best (the earlier three-win run) stands.
    func test_streaks_currentBrokenByLatestLoss_bestPreserved() {
        let stats = MatchStatistics(matches: [
            makeMatch(winner: "b", daysAgo: 0),  // latest — loss
            makeMatch(winner: "a", daysAgo: 1),
            makeMatch(winner: "a", daysAgo: 2),
            makeMatch(winner: "a", daysAgo: 3),
            makeMatch(winner: "b", daysAgo: 4),  // oldest
        ])

        XCTAssertEqual(stats.currentStreak, 0)
        XCTAssertEqual(stats.bestStreak, 3)
    }

    /// The current streak is the run ending at the most recent match, counted
    /// however the matches arrive.
    func test_streaks_currentRunEndsAtLatestWin() {
        let stats = MatchStatistics(matches: [
            makeMatch(winner: "a", daysAgo: 1),
            makeMatch(winner: "a", daysAgo: 0),  // latest — win
            makeMatch(winner: "b", daysAgo: 2),
        ])

        XCTAssertEqual(stats.currentStreak, 2)
        XCTAssertEqual(stats.bestStreak, 2)
    }

    func test_streaks_alternating() {
        let stats = MatchStatistics(matches: [
            makeMatch(winner: "a", daysAgo: 3),
            makeMatch(winner: "b", daysAgo: 2),
            makeMatch(winner: "a", daysAgo: 1),
            makeMatch(winner: "b", daysAgo: 0),  // latest — loss
        ])

        XCTAssertEqual(stats.currentStreak, 0)
        XCTAssertEqual(stats.bestStreak, 1)
    }

    // MARK: - Golden points

    func test_goldenPoints_countedFromGameLog() {
        let stats = MatchStatistics(matches: [
            makeMatch(gameHistory: [
                goldenPointGame(winner: .a),
                goldenPointGame(winner: .b),
                plainGame(winner: .a),        // not a golden point
            ]),
            makeMatch(gameHistory: [goldenPointGame(winner: .a)]),
        ])

        XCTAssertEqual(stats.goldenPointsWon, 2)
        XCTAssertEqual(stats.goldenPointsLost, 1)
    }

    func test_goldenPoints_noneWhenNoGoldenPointGames() {
        let stats = MatchStatistics(matches: [
            makeMatch(gameHistory: [plainGame(winner: .a), plainGame(winner: .b)]),
        ])

        XCTAssertEqual(stats.goldenPointsWon, 0)
        XCTAssertEqual(stats.goldenPointsLost, 0)
    }

    // MARK: - Super-tiebreaks

    func test_superTiebreaks_countedFromGameLog() {
        let stats = MatchStatistics(matches: [
            makeMatch(gameHistory: [tiebreakGame(winner: .a), plainGame(winner: .a)]),
            makeMatch(gameHistory: [tiebreakGame(winner: .b)]),
            makeMatch(gameHistory: [tiebreakGame(winner: .a)]),
        ])

        XCTAssertEqual(stats.superTiebreaksWon, 2)
        XCTAssertEqual(stats.superTiebreaksLost, 1)
    }

    /// A tennis set tiebreak also carries `isTiebreak`, but it is not the beach
    /// 6-6 super-tiebreak the record is about — it must not be counted.
    func test_superTiebreaks_excludeTennisSetTiebreaks() {
        let stats = MatchStatistics(matches: [
            makeMatch(matchTypeRaw: "tennis", gameHistory: [tiebreakGame(winner: .a)]),
            makeMatch(matchTypeRaw: "beachTennis", gameHistory: [tiebreakGame(winner: .a)]),
        ])

        XCTAssertEqual(stats.superTiebreaksWon, 1, "only the beach super-tiebreak counts")
        XCTAssertEqual(stats.superTiebreaksLost, 0)
    }

    // MARK: - Sport split

    func test_sportSplit_countsPerSport() {
        let stats = MatchStatistics(matches: [
            makeMatch(matchTypeRaw: "beachTennis"),
            makeMatch(matchTypeRaw: "tennis"),
            makeMatch(matchTypeRaw: "beachTennis"),
        ])

        XCTAssertEqual(stats.beachMatches, 2)
        XCTAssertEqual(stats.tennisMatches, 1)
        XCTAssertEqual(stats.beachMatches + stats.tennisMatches, stats.matchesPlayed)
    }

    // MARK: - Court time

    func test_courtTime_totalAndAverage() {
        let stats = MatchStatistics(matches: [
            makeMatch(duration: 1_800),
            makeMatch(duration: 3_600),
            makeMatch(duration: 2_400),
        ])

        XCTAssertEqual(stats.totalDuration, 7_800)
        XCTAssertEqual(stats.averageDuration, 2_600, accuracy: 1e-9)
    }
}
