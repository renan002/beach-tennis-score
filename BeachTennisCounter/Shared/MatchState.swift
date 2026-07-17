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

struct GameRecord: Codable, Sendable {
    let gameNumber: Int
    let setScoreA: Int
    let setScoreB: Int
    let winner: Team
    let isTiebreak: Bool
    var gameScoreDisplay: String?
}

struct SetRecord: Codable, Sendable {
    let setNumber: Int
    let gamesA: Int
    let gamesB: Int
    let winner: Team
    let isTiebreak: Bool
}

struct MatchState: Codable, Sendable {
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
