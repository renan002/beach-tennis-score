import Foundation

enum WatchMessageKey {
    static let type = "type"
    static let matchId = "matchId"
    static let setScoreA = "setScoreA"
    static let setScoreB = "setScoreB"
    static let setsWonA = "setsWonA"
    static let setsWonB = "setsWonB"
    static let winner = "winner"
    static let duration = "duration"
    static let date = "date"
    static let teamAColor = "teamAColor"
    static let teamBColor = "teamBColor"
    static let gameHistory = "gameHistory"
    static let setHistory = "setHistory"
    static let matchType = "matchType"
    static let sportSetting = "sportSetting"
}

enum WatchMessageType {
    static let matchResult = "matchResult"
    static let colorUpdate = "colorUpdate"
}

struct MatchResultPayload: Codable, Sendable {
    let matchId: UUID
    let setScoreA: Int
    let setScoreB: Int
    let setsWonA: Int
    let setsWonB: Int
    let winner: Team
    let duration: TimeInterval
    let date: Date
    let gameHistory: [GameRecord]
    let setHistory: [SetRecord]
    let matchType: MatchType

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.matchResult,
            WatchMessageKey.matchId: matchId.uuidString,
            WatchMessageKey.setScoreA: setScoreA,
            WatchMessageKey.setScoreB: setScoreB,
            WatchMessageKey.setsWonA: setsWonA,
            WatchMessageKey.setsWonB: setsWonB,
            WatchMessageKey.winner: winner.rawValue,
            WatchMessageKey.duration: duration,
            WatchMessageKey.date: ISO8601DateFormatter().string(from: date),
            WatchMessageKey.matchType: matchType.rawValue
        ]
        if let data = try? JSONEncoder().encode(gameHistory) {
            dict[WatchMessageKey.gameHistory] = data
        }
        if let data = try? JSONEncoder().encode(setHistory) {
            dict[WatchMessageKey.setHistory] = data
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

        let matchId = (dict[WatchMessageKey.matchId] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()

        let setsWonA = dict[WatchMessageKey.setsWonA] as? Int ?? 0
        let setsWonB = dict[WatchMessageKey.setsWonB] as? Int ?? 0

        let matchTypeRaw = dict[WatchMessageKey.matchType] as? String ?? "beachTennis"
        let matchType = MatchType(rawValue: matchTypeRaw) ?? .beachTennis

        let gameHistory: [GameRecord]
        if let data = dict[WatchMessageKey.gameHistory] as? Data,
           let records = try? JSONDecoder().decode([GameRecord].self, from: data) {
            gameHistory = records
        } else {
            gameHistory = []
        }

        let setHistory: [SetRecord]
        if let data = dict[WatchMessageKey.setHistory] as? Data,
           let records = try? JSONDecoder().decode([SetRecord].self, from: data) {
            setHistory = records
        } else {
            setHistory = []
        }

        return MatchResultPayload(
            matchId: matchId,
            setScoreA: a, setScoreB: b,
            setsWonA: setsWonA, setsWonB: setsWonB,
            winner: winner, duration: duration, date: date,
            gameHistory: gameHistory, setHistory: setHistory,
            matchType: matchType
        )
    }
}
