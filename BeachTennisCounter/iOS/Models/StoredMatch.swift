import Foundation
import SwiftData

@Model
final class StoredMatch {
    var id: UUID
    var date: Date
    var setScoreA: Int
    var setScoreB: Int
    // Property-level defaults (not just init defaults): SwiftData lightweight
    // migration only accepts an added non-optional attribute when it is
    // declared with a default here. Without these, a 1.1.x store fails to
    // migrate (CocoaError 134110). See #47.
    var setsWonA: Int = 0
    var setsWonB: Int = 0
    var winner: String
    var duration: TimeInterval
    var gameHistoryData: Data = Data()
    var setHistoryData: Data = Data()
    var matchTypeRaw: String = "beachTennis"
    // Team Names as they were when the match was played — immutable history.
    // Property-level defaults, same #47 reasoning as setsWonA/B above: a store
    // written without these attributes must migrate in place, materializing
    // empty names. Empty means unnamed; display falls back to "Team A"/"Team B".
    var teamAName: String = ""
    var teamBName: String = ""
    // Workout stats from the watch's HealthKit session, `nil` when absent
    // (HealthKit denied, Health Monitoring off, or a pre-feature match). Optional
    // with a `nil` default satisfies the #47 lightweight-migration rule — an older
    // store migrates in place, leaving these null.
    var activeCalories: Double? = nil
    var avgHeartRate: Double? = nil

    init(
        id: UUID = UUID(),
        date: Date,
        setScoreA: Int,
        setScoreB: Int,
        setsWonA: Int = 0,
        setsWonB: Int = 0,
        winner: String,
        duration: TimeInterval,
        gameHistoryData: Data = Data(),
        setHistoryData: Data = Data(),
        matchTypeRaw: String = "beachTennis",
        teamAName: String = "",
        teamBName: String = "",
        activeCalories: Double? = nil,
        avgHeartRate: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.setScoreA = setScoreA
        self.setScoreB = setScoreB
        self.setsWonA = setsWonA
        self.setsWonB = setsWonB
        self.winner = winner
        self.duration = duration
        self.gameHistoryData = gameHistoryData
        self.setHistoryData = setHistoryData
        self.matchTypeRaw = matchTypeRaw
        self.teamAName = teamAName
        self.teamBName = teamBName
        self.activeCalories = activeCalories
        self.avgHeartRate = avgHeartRate
    }

    /// A detached copy for inserting into another context. Copies every
    /// persisted property — a match restored from a Quarantined Store must
    /// round-trip whole, so a new field belongs here too.
    convenience init(copying other: StoredMatch) {
        self.init(
            id: other.id,
            date: other.date,
            setScoreA: other.setScoreA,
            setScoreB: other.setScoreB,
            setsWonA: other.setsWonA,
            setsWonB: other.setsWonB,
            winner: other.winner,
            duration: other.duration,
            gameHistoryData: other.gameHistoryData,
            setHistoryData: other.setHistoryData,
            matchTypeRaw: other.matchTypeRaw,
            teamAName: other.teamAName,
            teamBName: other.teamBName,
            activeCalories: other.activeCalories,
            avgHeartRate: other.avgHeartRate
        )
    }

    var matchType: MatchType { MatchType(rawValue: matchTypeRaw) ?? .beachTennis }
    var gameHistory: [GameRecord] { (try? JSONDecoder().decode([GameRecord].self, from: gameHistoryData)) ?? [] }
    var setHistory: [SetRecord] { (try? JSONDecoder().decode([SetRecord].self, from: setHistoryData)) ?? [] }
    var winnerTeam: Team? { Team(rawValue: winner) }

    /// True when the match is scored in sets — a tennis match with at least one
    /// set on the board. Beach tennis never is, and a tennis match abandoned
    /// inside its first set has no set to show, so both fall back to games.
    var isSetScored: Bool {
        matchType == .tennis && (setsWonA > 0 || setsWonB > 0)
    }

    var scoreDisplay: String {
        isSetScored ? "\(setsWonA) – \(setsWonB)" : "\(setScoreA) – \(setScoreB)"
    }

    /// The label for `team`: its stored Team Name, or the localized
    /// "Team A"/"Team B" fallback when the name is empty. Resolved to a plain
    /// String here so a user-entered name never reaches the String Catalog —
    /// only the fallback literal is localized. Mirrors
    /// `MatchState.teamName(for:)` on the scoring side.
    func teamName(for team: Team) -> String {
        let name = team == .a ? teamAName : teamBName
        return name.isEmpty ? team.displayName : name
    }

    /// The score flanked by the Team Names — "Renan 6 – 3 Visitors".
    var scoreLineDisplay: String {
        "\(teamName(for: .a)) \(scoreDisplay) \(teamName(for: .b))"
    }

    /// The winning side's Team Name, or "" when `winner` names no known side.
    var winnerDisplayName: String {
        winnerTeam.map { teamName(for: $0) } ?? ""
    }

    var durationDisplay: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// `nil` when no workout data was recorded — the detail row hides.
    var activeCaloriesDisplay: String? {
        guard let activeCalories else { return nil }
        return "\(Int(activeCalories.rounded())) kcal"
    }

    /// `nil` when no workout data was recorded — the detail row hides.
    var avgHeartRateDisplay: String? {
        guard let avgHeartRate else { return nil }
        return "\(Int(avgHeartRate.rounded())) bpm"
    }
}
