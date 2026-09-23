import Foundation

/// A Ruleset decoded from data.
enum RulesetCodecError: Error {
    case malformed
}

struct Ruleset: Codable, Equatable, Sendable {
    enum CodingVersion: String, Codable {
        case v1
    }

    enum StoredPayload: String, Codable {
        case pingPong
    }

    /// Coding keys, private so neither legacy fields nor the ping payload can be
    /// missed by a switch written over the *decoded* value. `encode` writes only
    /// the keys a sport needs; `decode` materializes `pingPong` from the payload
    /// key or drops it when the sport doesn't need it.
    private enum CodingKeys: String, CodingKey {
        case codingVersion, identifier, name, sport, hasSets
        case gamesToWinMatch, tiebreakAtGames, tiebreakPointsToWin, tiebreakWinByTwo, setsToWinMatch
        case payloadType, pingPong
    }

    private let codingVersion: CodingVersion
    let identifier: UUID
    let name: String
    let sport: MatchType
    let hasSets: Bool
    let gamesToWinMatch: Int
    let tiebreakAtGames: Int?
    let tiebreakPointsToWin: Int
    let tiebreakWinByTwo: Bool
    let setsToWinMatch: Int?
    /// Ping pong's own rules, `nil` for every other sport. The whole payload —
    /// target, best-of, serve mode, name, identity — is stamped by value onto a
    /// match at its start (ADR 0006); a look-up of today's setting never
    /// rewrites a match already played.
    let pingPong: PingPongRuleset?

    init(
        codingVersion: CodingVersion = .v1,
        identifier: UUID,
        name: String,
        sport: MatchType,
        hasSets: Bool,
        gamesToWinMatch: Int,
        tiebreakAtGames: Int?,
        tiebreakPointsToWin: Int,
        tiebreakWinByTwo: Bool,
        setsToWinMatch: Int?,
        pingPong: PingPongRuleset? = nil
    ) {
        self.codingVersion = codingVersion
        self.identifier = identifier
        self.name = name
        self.sport = sport
        self.hasSets = hasSets
        self.gamesToWinMatch = gamesToWinMatch
        self.tiebreakAtGames = tiebreakAtGames
        self.tiebreakPointsToWin = tiebreakPointsToWin
        self.tiebreakWinByTwo = tiebreakWinByTwo
        self.setsToWinMatch = setsToWinMatch
        self.pingPong = pingPong
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        codingVersion = try c.decodeIfPresent(CodingVersion.self, forKey: .codingVersion) ?? .v1
        identifier = try c.decode(UUID.self, forKey: .identifier)
        name = try c.decode(String.self, forKey: .name)
        sport = try c.decode(MatchType.self, forKey: .sport)
        hasSets = try c.decodeIfPresent(Bool.self, forKey: .hasSets) ?? false
        gamesToWinMatch = try c.decodeIfPresent(Int.self, forKey: .gamesToWinMatch) ?? 0
        tiebreakAtGames = try c.decodeIfPresent(Int.self, forKey: .tiebreakAtGames)
        tiebreakPointsToWin = try c.decodeIfPresent(Int.self, forKey: .tiebreakPointsToWin) ?? 0
        tiebreakWinByTwo = try c.decodeIfPresent(Bool.self, forKey: .tiebreakWinByTwo) ?? true
        setsToWinMatch = try c.decodeIfPresent(Int.self, forKey: .setsToWinMatch)

        let payloadType = try c.decodeIfPresent(StoredPayload.self, forKey: .payloadType)
        switch payloadType {
        case .pingPong:
            guard sport == .pingPong,
                  let ping = try c.decodeIfPresent(PingPongRuleset.self, forKey: .pingPong)
            else { throw RulesetCodecError.malformed }
            pingPong = ping
        case .none:
            // A legacy encoded blob — a preset/custom for beach or tennis — has
            // no payload key. It must still decode (ADR 0006), materializing
            // `nil` ping rules.
            guard sport == .pingPong else {
                pingPong = nil
                return
            }
            // A ping ruleset encoded without a payload is malformed — reject
            // rather than silently interpreting it as legacy.
            throw RulesetCodecError.malformed
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(codingVersion, forKey: .codingVersion)
        try c.encode(identifier, forKey: .identifier)
        try c.encode(name, forKey: .name)
        try c.encode(sport, forKey: .sport)
        try c.encode(hasSets, forKey: .hasSets)
        try c.encode(gamesToWinMatch, forKey: .gamesToWinMatch)
        try c.encode(tiebreakAtGames, forKey: .tiebreakAtGames)
        try c.encode(tiebreakPointsToWin, forKey: .tiebreakPointsToWin)
        try c.encode(tiebreakWinByTwo, forKey: .tiebreakWinByTwo)
        try c.encode(setsToWinMatch, forKey: .setsToWinMatch)
        if let ping = pingPong {
            try c.encode(StoredPayload.pingPong, forKey: .payloadType)
            try c.encode(ping, forKey: .pingPong)
        }
    }

    /// Builds the ping pong Ruleset wrapping `rules`. The legacy fields are
    /// populated from the ping value so the flat encoder/wire views that reuse
    /// `gamesToWinMatch` etc. still agree with the payload.
    static func pingPong(_ rules: PingPongRuleset) -> Ruleset {
        Ruleset(
            identifier: rules.identifier,
            name: rules.name,
            sport: .pingPong,
            hasSets: false,
            gamesToWinMatch: rules.gamesToWinMatch,
            tiebreakAtGames: nil,
            tiebreakPointsToWin: 0,
            tiebreakWinByTwo: rules.winByTwo,
            setsToWinMatch: nil,
            pingPong: rules
        )
    }

    static func preset(for sport: MatchType) -> Ruleset {
        switch sport {
        case .beachTennis:
            Ruleset(
                identifier: UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!,
                name: "Beach Tennis",
                sport: .beachTennis,
                hasSets: false,
                gamesToWinMatch: 6,
                tiebreakAtGames: 6,
                tiebreakPointsToWin: 7,
                tiebreakWinByTwo: true,
                setsToWinMatch: nil
            )
        case .tennis:
            Ruleset(
                identifier: UUID(uuidString: "F721E1F8-C36C-495A-93FC-0C247A3E6E5F")!,
                name: "Tennis",
                sport: .tennis,
                hasSets: true,
                gamesToWinMatch: 6,
                tiebreakAtGames: 6,
                tiebreakPointsToWin: 7,
                tiebreakWinByTwo: true,
                setsToWinMatch: 2
            )
        case .pingPong:
            Ruleset(
                identifier: PingPongRuleset.oficial.identifier,
                name: PingPongRuleset.oficial.name,
                sport: .pingPong,
                hasSets: false,
                gamesToWinMatch: PingPongRuleset.oficial.gamesToWinMatch,
                tiebreakAtGames: nil,
                tiebreakPointsToWin: 0,
                tiebreakWinByTwo: true,
                setsToWinMatch: nil,
                pingPong: .oficial
            )
        }
    }
}
