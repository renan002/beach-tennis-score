import XCTest
@testable import BeachTennisCounter

/// The seeder's pure half. The affordance that calls it is `#if DEV` and so is
/// not in this build, but the generator is `#if DEBUG` and therefore is — the
/// point of the split is that CI can prove seeded matches are well-formed
/// without the Dev-only UI existing.
final class MatchSeederTests: XCTestCase {

    private let reference = Date(timeIntervalSince1970: 1_750_000_000)

    private func params(
        sport: SeedParameters.Sport = .beachTennis,
        count: Int = 12,
        strength: Double = 0.55,
        seed: UInt64 = 42
    ) -> SeedParameters {
        SeedParameters(
            sport: sport,
            count: count,
            from: reference.addingTimeInterval(-180 * 86_400),
            to: reference,
            teamAStrength: strength,
            seed: seed
        )
    }

    // MARK: - Reproducibility

    /// The reason the seeder takes a seed at all: a bug found in a seeded store
    /// has to be reproducible rather than re-rolled.
    func testSameSeedProducesIdenticalMatches() {
        let first = MatchSeeder.makeMatches(params())
        let second = MatchSeeder.makeMatches(params())

        XCTAssertEqual(first.count, second.count)
        for (a, b) in zip(first, second) {
            XCTAssertEqual(a.state.setScoreA, b.state.setScoreA)
            XCTAssertEqual(a.state.setScoreB, b.state.setScoreB)
            XCTAssertEqual(a.state.winner, b.state.winner)
            XCTAssertEqual(a.state.gameHistory.count, b.state.gameHistory.count)
            XCTAssertEqual(a.date, b.date)
            XCTAssertEqual(a.duration, b.duration)
        }
    }

    func testDifferentSeedProducesDifferentMatches() {
        let first = MatchSeeder.makeMatches(params(seed: 1))
        let second = MatchSeeder.makeMatches(params(seed: 2))

        let firstScores = first.map { "\($0.state.setScoreA)-\($0.state.setScoreB)@\($0.date.timeIntervalSince1970)" }
        let secondScores = second.map { "\($0.state.setScoreA)-\($0.state.setScoreB)@\($0.date.timeIntervalSince1970)" }
        XCTAssertNotEqual(firstScores, secondScores)
    }

    // MARK: - Population

    func testProducesRequestedCount() {
        XCTAssertEqual(MatchSeeder.makeMatches(params(count: 37)).count, 37)
    }

    func testZeroCountProducesNothing() {
        XCTAssertTrue(MatchSeeder.makeMatches(params(count: 0)).isEmpty)
    }

    func testDatesFallInsideTheRequestedRange() {
        let p = params(count: 50)
        for match in MatchSeeder.makeMatches(p) {
            XCTAssertGreaterThanOrEqual(match.date, p.from)
            XCTAssertLessThanOrEqual(match.date, p.to)
            // The state carries the same date, so a seeded match's start time
            // agrees with the row it is stored in.
            XCTAssertEqual(match.state.matchStartDate, match.date)
        }
    }

    func testSportSelectionIsHonoured() {
        for match in MatchSeeder.makeMatches(params(sport: .beachTennis, count: 20)) {
            XCTAssertEqual(match.state.matchType, .beachTennis)
        }
        for match in MatchSeeder.makeMatches(params(sport: .tennis, count: 20)) {
            XCTAssertEqual(match.state.matchType, .tennis)
        }
    }

    func testMixedProducesBothSports() {
        let types = Set(MatchSeeder.makeMatches(params(sport: .mixed, count: 40)).map(\.state.matchType))
        XCTAssertEqual(types, [.beachTennis, .tennis])
    }

    // MARK: - Seeded matches are shaped like played matches

    func testEveryMatchIsFinished() {
        for match in MatchSeeder.makeMatches(params(sport: .mixed, count: 40)) {
            XCTAssertTrue(match.state.isMatchOver)
            XCTAssertNotNil(match.state.winner)
            XCTAssertFalse(match.state.gameHistory.isEmpty)
        }
    }

    /// A beach tennis match is first to 6 games, 7 when it goes to 5-5 or
    /// through the 6-6 super tiebreak — so the winner always ends on 6 or 7,
    /// ahead. Anything else means the seeder is not really driving `ScoreEngine`.
    func testBeachTennisFinalScoresAreLegal() {
        for match in MatchSeeder.makeMatches(params(count: 60)) {
            let state = match.state
            let winnerGames = state.setScore(for: state.winner!)
            let loserGames = state.setScore(for: state.winner!.other)
            XCTAssertTrue([6, 7].contains(winnerGames), "winner finished on \(winnerGames) games")
            XCTAssertGreaterThan(winnerGames, loserGames)
        }
    }

    /// Tennis is best of 3: the winner takes exactly two sets, and the Set Log
    /// holds one record per set played.
    func testTennisFinalScoresAreLegal() {
        for match in MatchSeeder.makeMatches(params(sport: .tennis, count: 30)) {
            let state = match.state
            XCTAssertEqual(state.setsWon(for: state.winner!), 2)
            XCTAssertLessThan(state.setsWon(for: state.winner!.other), 2)
            XCTAssertEqual(state.setHistory.count, state.setsWonA + state.setsWonB)
        }
    }

    /// Estatísticas reads the Game Log, so each record's running score has to be
    /// the score after that game — the thing a synthesised match would get
    /// wrong.
    func testGameLogRunningScoresAreConsistent() {
        for match in MatchSeeder.makeMatches(params(count: 20)) {
            var a = 0
            var b = 0
            for (index, game) in match.state.gameHistory.enumerated() {
                XCTAssertEqual(game.gameNumber, index + 1)
                if game.winner == .a { a += 1 } else { b += 1 }
                XCTAssertEqual(game.setScoreA, a)
                XCTAssertEqual(game.setScoreB, b)
            }
        }
    }

    func testDurationTracksPointsPlayed() {
        for match in MatchSeeder.makeMatches(params(sport: .mixed, count: 20)) {
            XCTAssertGreaterThan(match.duration, 0)
            XCTAssertEqual(
                match.duration.truncatingRemainder(dividingBy: MatchSeeder.secondsPerPoint),
                0,
                accuracy: 0.001
            )
        }
    }

    /// Not a rule of the game — a check that the strength knob does something.
    func testStrengthSkewsResults() {
        let strong = MatchSeeder.makeMatches(params(count: 60, strength: 0.65))
        let winsForA = strong.filter { $0.state.winner == .a }.count
        XCTAssertGreaterThan(winsForA, 30)
    }

    func testTeamNamesAreStamped() {
        let matches = MatchSeeder.makeMatches(params(count: 5), teamAName: "Nós", teamBName: "Eles")
        for match in matches {
            XCTAssertEqual(match.state.teamAName, "Nós")
            XCTAssertEqual(match.state.teamBName, "Eles")
        }
    }

    // MARK: - Conversion to the stored form

    func testStoredMatchCarriesTheSeededMatchWhole() {
        let seeded = MatchSeeder.makeMatches(params(sport: .tennis, count: 1)).first!
        let stored = StoredMatch(seeded: seeded)

        XCTAssertEqual(stored.date, seeded.date)
        XCTAssertEqual(stored.duration, seeded.duration)
        XCTAssertEqual(stored.matchType, .tennis)
        XCTAssertEqual(stored.winner, seeded.state.winner?.rawValue)
        XCTAssertEqual(stored.setsWonA, seeded.state.setsWonA)
        XCTAssertEqual(stored.setsWonB, seeded.state.setsWonB)
        XCTAssertEqual(stored.gameHistory.count, seeded.state.gameHistory.count)
        XCTAssertEqual(stored.setHistory.count, seeded.state.setHistory.count)
        // Workout stats come from a real HealthKit session on the watch. A
        // seeded match never had one, and inventing heart rates would make
        // Estatísticas report data it never had.
        XCTAssertNil(stored.activeCalories)
        XCTAssertNil(stored.avgHeartRate)
    }
}
