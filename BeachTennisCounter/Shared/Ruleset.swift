import Foundation

struct Ruleset: Codable, Equatable, Sendable {
    enum CodingVersion: String, Codable {
        case v1
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
        setsToWinMatch: Int?
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
    }

    private static func presetUUID<S: RawRepresentable>(_ token: S) -> UUID where S.RawValue == String {
        let uuidMap: [String: String] = [
            MatchType.beachTennis.rawValue: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            MatchType.tennis.rawValue: "F721E1F8-C36C-495A-93FC-0C247A3E6E5F",
        ]
        guard let uuidString = uuidMap[token.rawValue],
              let uuid = UUID(uuidString: uuidString)
        else { fatalError("Unknown preset key: \(token.rawValue)") }
        return uuid
    }

    static func preset(for sport: MatchType) -> Ruleset {
        switch sport {
        case .beachTennis:
            Ruleset(
                identifier: presetUUID(MatchType.beachTennis),
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
                identifier: presetUUID(MatchType.tennis),
                name: "Tennis",
                sport: .tennis,
                hasSets: true,
                gamesToWinMatch: 6,
                tiebreakAtGames: 6,
                tiebreakPointsToWin: 7,
                tiebreakWinByTwo: true,
                setsToWinMatch: 2
            )
        }
    }
}
