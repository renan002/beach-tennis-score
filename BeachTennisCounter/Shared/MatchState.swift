import Foundation

enum Team: String, Codable, Sendable {
    case a, b

    var other: Team { self == .a ? .b : .a }
    var displayName: String {
        self == .a
            ? NSLocalizedString("Team A", comment: "")
            : NSLocalizedString("Team B", comment: "")
    }
}

enum MatchType: String, Codable, Sendable, CaseIterable {
    case beachTennis = "beachTennis"
    case tennis = "tennis"

    var displayName: String {
        switch self {
        case .beachTennis: return String(localized: "Beach Tennis")
        case .tennis: return String(localized: "Tennis")
        }
    }

    var icon: String {
        switch self {
        case .beachTennis: return "beach.umbrella"
        case .tennis: return "tennis.racket"
        }
    }

    // Beach tennis displays each game as a "Set" in every language, never by
    // locale — see CONTEXT.md "Scoring units".
    func gameLabel(_ number: Int) -> String {
        switch self {
        case .beachTennis: return String(localized: "Set \(number)")
        case .tennis: return String(localized: "Game \(number)")
        }
    }

    var gamesSectionTitle: String {
        switch self {
        case .beachTennis: return String(localized: "Sets")
        case .tennis: return String(localized: "Games")
        }
    }

    /// What a tennis match's sets are called. Beach tennis has no sets of its
    /// own — it labels *games* "Sets" via `gamesSectionTitle` — so the two
    /// sport's scoring vocabulary still lives in this one type.
    static let setsSectionTitle = String(localized: "Sets")
}

enum PointScore: Int, Codable, Sendable, CaseIterable {
    case zero, fifteen, thirty, forty

    var display: String {
        switch self {
        case .zero:    return "0"
        case .fifteen: return "15"
        case .thirty:  return "30"
        case .forty:   return "40"
        }
    }

    var next: PointScore? {
        switch self {
        case .zero:    return .fifteen
        case .fifteen: return .thirty
        case .thirty:  return .forty
        case .forty:   return nil
        }
    }
}

struct GameRecord: Codable, Sendable, Equatable {
    /// The `gameScoreDisplay` a golden-point (beach tennis sudden death) game
    /// records. The only Game Log signal that a game was decided at the golden
    /// point, so `ScoreEngine` writes it and Estatísticas reads it — one literal
    /// keeps the two from drifting apart.
    static let goldenPointDisplay = "GP"

    let gameNumber: Int
    let setScoreA: Int
    let setScoreB: Int
    let winner: Team
    let isTiebreak: Bool
    var gameScoreDisplay: String?
    /// Per-sport numeric points at game end. Defaults so records persisted
    /// before these fields existed decode without migrating — `nil` means the
    /// record was written before the field was added.
    let pointsA: Int?
    let pointsB: Int?

    init(
        gameNumber: Int,
        setScoreA: Int,
        setScoreB: Int,
        winner: Team,
        isTiebreak: Bool,
        gameScoreDisplay: String? = nil,
        pointsA: Int? = nil,
        pointsB: Int? = nil
    ) {
        self.gameNumber = gameNumber
        self.setScoreA = setScoreA
        self.setScoreB = setScoreB
        self.winner = winner
        self.isTiebreak = isTiebreak
        self.gameScoreDisplay = gameScoreDisplay
        self.pointsA = pointsA
        self.pointsB = pointsB
    }
}

struct SetRecord: Codable, Sendable, Equatable {
    let setNumber: Int
    let gamesA: Int
    let gamesB: Int
    let winner: Team
    let isTiebreak: Bool
}

struct MatchState: Codable, Sendable, Equatable {
    var matchType: MatchType = .beachTennis

    // Current set / beach tennis games
    var setScoreA: Int = 0
    var setScoreB: Int = 0

    // Tennis: sets won
    var setsWonA: Int = 0
    var setsWonB: Int = 0
    var setHistory: [SetRecord] = []

    // Current game points
    var pointA: PointScore = .zero
    var pointB: PointScore = .zero

    // Beach Tennis: golden point at deuce
    var isGoldenPoint: Bool = false

    // Tennis: advantage at deuce (nil = deuce, .a/.b = has advantage)
    var advantageTeam: Team? = nil

    // Tiebreak
    var isTiebreak: Bool = false
    var tiebreakA: Int = 0
    var tiebreakB: Int = 0
    var tiebreakPointsPlayed: Int = 0
    var tiebreakFirstServer: Team = .a

    var servingTeam: Team = .a
    var initialServer: Team = .a

    var isMatchOver: Bool = false
    var winner: Team? = nil

    var matchStartDate: Date = Date()
    var gameHistory: [GameRecord] = []

    // Team Names in effect when this match was created. Empty means unnamed;
    // display sites resolve through `teamName(for:)`, never `Team.displayName`
    // directly, so the localized fallback stays the single source of truth.
    var teamAName: String = ""
    var teamBName: String = ""

    // Ruleset this match is played under, stamped by value at match creation
    // (ADR 0006). Default for backward-compatible decoding from old persisted
    // data that lacks the key.
    var ruleset: Ruleset = Ruleset.preset(for: .beachTennis)

    /// Builds the starting state for a brand-new match, stamping the Team Names
    /// and the Ruleset in effect at match start. Names and rules are copied by
    /// value, so a later Settings or Regras rename never rewrites a match already
    /// under way or already stored — history keeps the names and rules it was
    /// played with.
    static func newMatch(
        matchType: MatchType,
        initialServer: Team,
        teamAName: String = "",
        teamBName: String = ""
    ) -> MatchState {
        var s = MatchState()
        s.matchType = matchType
        s.servingTeam = initialServer
        s.initialServer = initialServer
        s.tiebreakFirstServer = initialServer
        s.teamAName = teamAName
        s.teamBName = teamBName
        s.ruleset = Ruleset.preset(for: matchType)
        return s
    }

    private enum CodingKeys: String, CodingKey {
        case matchType, setScoreA, setScoreB, setsWonA, setsWonB, setHistory
        case pointA, pointB, isGoldenPoint, advantageTeam
        case isTiebreak, tiebreakA, tiebreakB, tiebreakPointsPlayed, tiebreakFirstServer
        case servingTeam, initialServer, isMatchOver, winner, matchStartDate, gameHistory
        case teamAName, teamBName, ruleset
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        matchType = try container.decodeIfPresent(MatchType.self, forKey: .matchType) ?? .beachTennis
        setScoreA = try container.decodeIfPresent(Int.self, forKey: .setScoreA) ?? 0
        setScoreB = try container.decodeIfPresent(Int.self, forKey: .setScoreB) ?? 0
        setsWonA = try container.decodeIfPresent(Int.self, forKey: .setsWonA) ?? 0
        setsWonB = try container.decodeIfPresent(Int.self, forKey: .setsWonB) ?? 0
        setHistory = try container.decodeIfPresent([SetRecord].self, forKey: .setHistory) ?? []
        pointA = try container.decodeIfPresent(PointScore.self, forKey: .pointA) ?? .zero
        pointB = try container.decodeIfPresent(PointScore.self, forKey: .pointB) ?? .zero
        isGoldenPoint = try container.decodeIfPresent(Bool.self, forKey: .isGoldenPoint) ?? false
        advantageTeam = try container.decodeIfPresent(Team.self, forKey: .advantageTeam)
        isTiebreak = try container.decodeIfPresent(Bool.self, forKey: .isTiebreak) ?? false
        tiebreakA = try container.decodeIfPresent(Int.self, forKey: .tiebreakA) ?? 0
        tiebreakB = try container.decodeIfPresent(Int.self, forKey: .tiebreakB) ?? 0
        tiebreakPointsPlayed = try container.decodeIfPresent(Int.self, forKey: .tiebreakPointsPlayed) ?? 0
        tiebreakFirstServer = try container.decodeIfPresent(Team.self, forKey: .tiebreakFirstServer) ?? .a
        servingTeam = try container.decodeIfPresent(Team.self, forKey: .servingTeam) ?? .a
        initialServer = try container.decodeIfPresent(Team.self, forKey: .initialServer) ?? .a
        isMatchOver = try container.decodeIfPresent(Bool.self, forKey: .isMatchOver) ?? false
        winner = try container.decodeIfPresent(Team.self, forKey: .winner)
        matchStartDate = try container.decodeIfPresent(Date.self, forKey: .matchStartDate) ?? Date()
        gameHistory = try container.decodeIfPresent([GameRecord].self, forKey: .gameHistory) ?? []
        teamAName = try container.decodeIfPresent(String.self, forKey: .teamAName) ?? ""
        teamBName = try container.decodeIfPresent(String.self, forKey: .teamBName) ?? ""
        ruleset = try container.decodeIfPresent(Ruleset.self, forKey: .ruleset) ?? Ruleset.preset(for: matchType)
    }

    /// The label to show for `team`: its Team Name when set, otherwise the
    /// localized `Team.displayName` fallback. Forwards to `TeamName`, which
    /// states the rule for every display site.
    func teamName(for team: Team) -> String {
        TeamName.resolved(team == .a ? teamAName : teamBName, for: team)
    }

    func setScore(for team: Team) -> Int {
        team == .a ? setScoreA : setScoreB
    }

    func setsWon(for team: Team) -> Int {
        team == .a ? setsWonA : setsWonB
    }

    func point(for team: Team) -> PointScore {
        team == .a ? pointA : pointB
    }

    func tiebreakScore(for team: Team) -> Int {
        team == .a ? tiebreakA : tiebreakB
    }
}
