import Foundation
import SwiftData

@Model
final class StoredMatch {
    var id: UUID
    var date: Date
    var setScoreA: Int
    var setScoreB: Int
    var winner: String
    var duration: TimeInterval
    var gameHistoryData: Data = Data()

    init(id: UUID = UUID(), date: Date, setScoreA: Int, setScoreB: Int, winner: String, duration: TimeInterval, gameHistoryData: Data = Data()) {
        self.id = id
        self.date = date
        self.setScoreA = setScoreA
        self.setScoreB = setScoreB
        self.winner = winner
        self.duration = duration
        self.gameHistoryData = gameHistoryData
    }

    var gameHistory: [GameRecord] {
        (try? JSONDecoder().decode([GameRecord].self, from: gameHistoryData)) ?? []
    }

    var winnerTeam: Team? { Team(rawValue: winner) }

    var scoreDisplay: String { "\(setScoreA) – \(setScoreB)" }

    var durationDisplay: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
