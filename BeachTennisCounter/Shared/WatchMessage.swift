import Foundation

enum WatchMessageKey {
    static let type = "type"
    static let setScoreA = "setScoreA"
    static let setScoreB = "setScoreB"
    static let winner = "winner"
    static let duration = "duration"
    static let date = "date"
    static let teamAColor = "teamAColor"
    static let teamBColor = "teamBColor"
    static let gameHistory = "gameHistory"
}

enum WatchMessageType {
    static let matchResult = "matchResult"
    static let colorUpdate = "colorUpdate"
}

struct MatchResultPayload: Sendable {
    let setScoreA: Int
    let setScoreB: Int
    let winner: Team
    let duration: TimeInterval
    let date: Date
    let gameHistory: [GameRecord]

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.matchResult,
            WatchMessageKey.setScoreA: setScoreA,
            WatchMessageKey.setScoreB: setScoreB,
            WatchMessageKey.winner: winner.rawValue,
            WatchMessageKey.duration: duration,
            WatchMessageKey.date: ISO8601DateFormatter().string(from: date)
        ]
        if let data = try? JSONEncoder().encode(gameHistory) {
            dict[WatchMessageKey.gameHistory] = data
        }
        return dict
    }

    static func from(_ dict: [String: Any]) -> MatchResultPayload? {
        guard
            let a = dict[WatchMessageKey.setScoreA] as? Int,
            let b = dict[WatchMessageKey.setScoreB] as? Int,
            let winnerRaw = dict[WatchMessageKey.winner] as? String,
            let winner = Team(rawValue: winnerRaw),
            let duration = dict[WatchMessageKey.duration] as? TimeInterval,
            let dateStr = dict[WatchMessageKey.date] as? String,
            let date = ISO8601DateFormatter().date(from: dateStr)
        else { return nil }

        let gameHistory: [GameRecord]
        if let data = dict[WatchMessageKey.gameHistory] as? Data,
           let records = try? JSONDecoder().decode([GameRecord].self, from: data) {
            gameHistory = records
        } else {
            gameHistory = []
        }

        return MatchResultPayload(setScoreA: a, setScoreB: b, winner: winner,
                                  duration: duration, date: date, gameHistory: gameHistory)
    }
}
