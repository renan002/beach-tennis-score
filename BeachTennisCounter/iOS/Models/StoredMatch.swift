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
        matchTypeRaw: String = "beachTennis"
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
            matchTypeRaw: other.matchTypeRaw
        )
    }

    var matchType: MatchType { MatchType(rawValue: matchTypeRaw) ?? .beachTennis }
    var gameHistory: [GameRecord] { (try? JSONDecoder().decode([GameRecord].self, from: gameHistoryData)) ?? [] }
    var setHistory: [SetRecord] { (try? JSONDecoder().decode([SetRecord].self, from: setHistoryData)) ?? [] }
    var winnerTeam: Team? { Team(rawValue: winner) }

    var scoreDisplay: String {
        if matchType == .tennis && (setsWonA > 0 || setsWonB > 0) {
            return "\(setsWonA) – \(setsWonB)"
        }
        return "\(setScoreA) – \(setScoreB)"
    }

    var durationDisplay: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
