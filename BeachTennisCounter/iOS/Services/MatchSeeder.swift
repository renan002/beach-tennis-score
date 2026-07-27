import Foundation

// `DEBUG`, not `DEV`: this is the pure half of the seeder and it is unit-tested,
// and the test scheme runs under `Debug`. `Release` still never sees it. The
// *affordance* that calls it is `#if DEV` — the whole point of the split is that
// the generator can be tested by CI without the Dev-only UI existing.
#if DEBUG

/// A match the seeder produced. Everything a real match carries, in value form:
/// the `MatchState` that `ScoreEngine` actually played out, plus the two facts a
/// state does not hold — when it happened and how long it took.
struct SeededMatch: Sendable {
    let state: MatchState
    let date: Date
    let duration: TimeInterval
}

struct SeedParameters: Sendable {
    /// Which sport the population is drawn from. `mixed` decides per match, so a
    /// seeded history exercises the Match List's sport filter.
    enum Sport: String, CaseIterable, Identifiable, Sendable {
        case beachTennis, tennis, mixed
        var id: String { rawValue }
    }

    var sport: Sport = .beachTennis
    var count: Int = 20
    var from: Date
    var to: Date
    /// Team A's chance of winning any given point. Held near even on purpose:
    /// far from 0.5 and every match becomes a whitewash, which is not what a
    /// realistic history looks like.
    var teamAStrength: Double = 0.55
    /// The same seed and parameters produce byte-identical matches, so a bug
    /// found in a seeded store can be reproduced rather than re-rolled.
    var seed: UInt64 = 42

    init(
        sport: Sport = .beachTennis,
        count: Int = 20,
        from: Date? = nil,
        to: Date = Date(),
        teamAStrength: Double = 0.55,
        seed: UInt64 = 42
    ) {
        self.sport = sport
        self.count = count
        self.from = from ?? Calendar.current.date(byAdding: .month, value: -6, to: to) ?? to
        self.to = to
        self.teamAStrength = teamAStrength
        self.seed = seed
    }
}

/// SplitMix64 — a small, well-distributed seedable generator. Swift's
/// `SystemRandomNumberGenerator` cannot be seeded, and reproducibility is the
/// whole reason the seeder takes a seed at all.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum MatchSeeder {
    /// Seconds of match time attributed to each point played. A rough constant
    /// rather than a second random axis: duration only has to be plausible, and
    /// deriving it from the point count keeps a long match longer than a short
    /// one for free.
    static let secondsPerPoint: TimeInterval = 45

    /// A match that has not ended after this many points is abandoned rather
    /// than looped on forever. Unreachable with the real `ScoreEngine` — the
    /// longest possible match is far shorter — so it is a guard against a future
    /// scoring bug hanging the app, not an expected path.
    private static let pointLimit = 5_000

    /// Plays `params.count` matches through `ScoreEngine` point by point.
    ///
    /// Driving the real engine rather than synthesising scores is deliberate:
    /// Estatísticas reads the Game Log, so a shortcut here would produce stats
    /// that are subtly wrong. Every seeded match has a Game Log that a real
    /// match could have produced — valid scores, correct serve rotation, golden
    /// points recorded where they happened.
    static func makeMatches(
        _ params: SeedParameters,
        teamAName: String = "",
        teamBName: String = ""
    ) -> [SeededMatch] {
        guard params.count > 0 else { return [] }

        var rng = SeededGenerator(seed: params.seed)
        let earliest = min(params.from, params.to)
        let latest = max(params.from, params.to)
        let span = latest.timeIntervalSince(earliest)

        return (0..<params.count).map { _ in
            let matchType: MatchType
            switch params.sport {
            case .beachTennis: matchType = .beachTennis
            case .tennis:      matchType = .tennis
            case .mixed:       matchType = Bool.random(using: &rng) ? .tennis : .beachTennis
            }

            var state = MatchState.newMatch(
                matchType: matchType,
                initialServer: Bool.random(using: &rng) ? .a : .b,
                teamAName: teamAName,
                teamBName: teamBName
            )

            var pointsPlayed = 0
            while !state.isMatchOver && pointsPlayed < pointLimit {
                let winner: Team = Double.random(in: 0..<1, using: &rng) < params.teamAStrength ? .a : .b
                ScoreEngine.awardPoint(to: winner, state: &state)
                pointsPlayed += 1
            }

            let date = earliest.addingTimeInterval(
                span > 0 ? Double.random(in: 0...span, using: &rng) : 0
            )
            state.matchStartDate = date

            return SeededMatch(
                state: state,
                date: date,
                duration: Double(pointsPlayed) * secondsPerPoint
            )
        }
    }
}

extension StoredMatch {
    /// The seeder's counterpart to `PhoneSessionManager.insertMatch(from:)` —
    /// the phone's other writer builds a `StoredMatch` from a watch payload, this
    /// one builds it from a played-out `MatchState`. Workout stats stay `nil`:
    /// they come from a real HealthKit session on the watch, and inventing heart
    /// rates would make Estatísticas lie about data it never had.
    convenience init(seeded: SeededMatch) {
        let state = seeded.state
        self.init(
            date: seeded.date,
            setScoreA: state.setScoreA,
            setScoreB: state.setScoreB,
            setsWonA: state.setsWonA,
            setsWonB: state.setsWonB,
            winner: state.winner?.rawValue ?? "",
            duration: seeded.duration,
            gameHistoryData: (try? JSONEncoder().encode(state.gameHistory)) ?? Data(),
            setHistoryData: (try? JSONEncoder().encode(state.setHistory)) ?? Data(),
            matchTypeRaw: state.matchType.rawValue,
            teamAName: state.teamAName,
            teamBName: state.teamBName
        )
    }
}

#endif
