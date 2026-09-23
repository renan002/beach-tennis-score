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
    static let teamAName = "teamAName"
    static let teamBName = "teamBName"
    static let activeCalories = "activeCalories"
    static let avgHeartRate = "avgHeartRate"
    static let healthMonitoring = "healthMonitoring"
    static let healthAuthStatus = "healthAuthStatus"
    static let rulesetData = "rulesetData"
    // Ping pong's terminal numeric points. ADR 0005: the flat setScoreA/B
    // columns carry games won, so a ping match's points need a second tier.
    static let pingPointsA = "pingPointsA"
    static let pingPointsB = "pingPointsB"
}

enum WatchMessageType {
    static let matchResult = "matchResult"
    static let colorUpdate = "colorUpdate"
}

/// The watch→phone HealthKit authorization-status channel — the reverse
/// direction of the settings application-context path (`WatchSettings`).
///
/// The phone cannot query the watch app's HealthKit grant (authorization is
/// per-app, and no API reads another app's status), so the watch reports its
/// own status on change only. Decode returns `nil` for an absent or
/// unrecognized value, so the phone leaves its last-known status untouched
/// rather than clobbering it with garbage.
struct HealthAuthStatusMessage: Sendable, Equatable {
    let status: HealthAuthStatus

    func toApplicationContext() -> [String: Any] {
        [WatchMessageKey.healthAuthStatus: status.rawValue]
    }

    static func status(from dict: [String: Any]) -> HealthAuthStatus? {
        guard let raw = dict[WatchMessageKey.healthAuthStatus] as? String else { return nil }
        return HealthAuthStatus(rawValue: raw)
    }
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
    // Team Names stamped at match creation. Empty means unnamed. Join the
    // second decode tier below — a payload from an old watch lacks these keys
    // and must still decode, materializing empty strings rather than failing.
    let teamAName: String
    let teamBName: String
    // Workout stats snapshotted from the live builder at match end. `nil` is the
    // single uniform absent state — HealthKit denied, Health Monitoring off, or a
    // pre-feature payload. Second decode tier, same as the team names above.
    let activeCalories: Double?
    let avgHeartRate: Double?
    // The Ruleset stamped on the match at creation. Empty data = sport's preset,
    // which is also what a pre-Ruleset watch sends.
    let rulesetData: Data
    // Ping pong's terminal numeric points, `nil` for every other sport and for
    // a ping payload from a pre-feature watch. ADR 0005: setScoreA/B carry games
    // won, so the points a ping headline can fall back to need a second tier.
    let pingPointsA: Int?
    let pingPointsB: Int?

    init(
        matchId: UUID,
        setScoreA: Int,
        setScoreB: Int,
        setsWonA: Int,
        setsWonB: Int,
        winner: Team,
        duration: TimeInterval,
        date: Date,
        gameHistory: [GameRecord],
        setHistory: [SetRecord],
        matchType: MatchType,
        teamAName: String,
        teamBName: String,
        activeCalories: Double? = nil,
        avgHeartRate: Double? = nil,
        rulesetData: Data = Data(),
        pingPointsA: Int? = nil,
        pingPointsB: Int? = nil
    ) {
        self.matchId = matchId
        self.setScoreA = setScoreA
        self.setScoreB = setScoreB
        self.setsWonA = setsWonA
        self.setsWonB = setsWonB
        self.winner = winner
        self.duration = duration
        self.date = date
        self.gameHistory = gameHistory
        self.setHistory = setHistory
        self.matchType = matchType
        self.teamAName = teamAName
        self.teamBName = teamBName
        self.activeCalories = activeCalories
        self.avgHeartRate = avgHeartRate
        self.rulesetData = rulesetData
        self.pingPointsA = pingPointsA
        self.pingPointsB = pingPointsB
    }

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
            WatchMessageKey.matchType: matchType.rawValue,
            WatchMessageKey.teamAName: teamAName,
            WatchMessageKey.teamBName: teamBName
        ]
        if let activeCalories { dict[WatchMessageKey.activeCalories] = activeCalories }
        if let avgHeartRate { dict[WatchMessageKey.avgHeartRate] = avgHeartRate }
        if let data = try? JSONEncoder().encode(gameHistory) {
            dict[WatchMessageKey.gameHistory] = data
        }
        if let data = try? JSONEncoder().encode(setHistory) {
            dict[WatchMessageKey.setHistory] = data
        }
        dict[WatchMessageKey.rulesetData] = rulesetData
        // ADR 0005: the second-tier ping points only belong on a ping wire. A
        // non-ping payload omits them entirely — no empty numeric points for a
        // beach or tennis match. A ping payload's nil points are still written
        // by `if let`, matching the current watch which always stamps them.
        if matchType == .pingPong {
            if let pingPointsA { dict[WatchMessageKey.pingPointsA] = pingPointsA }
            if let pingPointsB { dict[WatchMessageKey.pingPointsB] = pingPointsB }
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

        let matchType: MatchType
        switch dict[WatchMessageKey.matchType] {
        case nil:
            matchType = .beachTennis
        case let raw as String:
            guard let decoded = MatchType(rawValue: raw) else { return nil }
            matchType = decoded
        default:
            return nil
        }

        let teamAName = dict[WatchMessageKey.teamAName] as? String ?? ""
        let teamBName = dict[WatchMessageKey.teamBName] as? String ?? ""

        let activeCalories = dict[WatchMessageKey.activeCalories] as? Double
        let avgHeartRate = dict[WatchMessageKey.avgHeartRate] as? Double

        let rulesetData = dict[WatchMessageKey.rulesetData] as? Data ?? Data()

        let pingPointsA: Int?
        let pingPointsB: Int?

        // ADR 0006 validation: ping pong's stamped Ruleset is mandatory. A ping
        // payload without one, or with one that does not decode to a playable
        // ping ruleset, is corrupt — materializing it would silently represent
        // the match with the beach preset's rules. Legacy beach/tennis payloads
        // predate the feature and keep their fallback to the sport's preset.
        if matchType == .pingPong {
            guard !rulesetData.isEmpty else { return nil }
            guard let stamped = try? JSONDecoder().decode(Ruleset.self, from: rulesetData),
                  stamped.sport == .pingPong,
                  stamped.pingPong?.isValid == true
            else { return nil }

            // Distinguish a present-but-malformed key from a pre-feature absence:
            // `as? Int` collapses both to nil. Both absent stays legal for a
            // legacy ping wire, but a present pair must contain nonnegative Ints.
            switch (dict[WatchMessageKey.pingPointsA], dict[WatchMessageKey.pingPointsB]) {
            case (nil, nil):
                pingPointsA = nil
                pingPointsB = nil
            case (let rawA?, let rawB?):
                guard let a = rawA as? Int, let b = rawB as? Int,
                      a >= 0, b >= 0
                else { return nil }
                pingPointsA = a
                pingPointsB = b
            default:
                return nil
            }
        } else {
            pingPointsA = nil
            pingPointsB = nil
        }

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
            matchType: matchType,
            teamAName: teamAName, teamBName: teamBName,
            activeCalories: activeCalories, avgHeartRate: avgHeartRate,
            rulesetData: rulesetData,
            pingPointsA: pingPointsA, pingPointsB: pingPointsB
        )
    }
}
