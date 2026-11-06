import Foundation

/// How the serve rotates in ping pong.
///
/// The two interval modes carry the deuce rule with them: from `(target−1,
/// target−1)` the serve alternates every point (10–10 in an 11-point set, 20–20
/// in a 21-point one), derived rather than configured. Rally mode has no deuce
/// case at all — the serve follows the point winner, always. The raw values are
/// storage keys, never localized and never renamed.
enum PingPongServeMode: String, Codable, CaseIterable, Sendable {
    case every2 = "every2"
    case every5 = "every5"
    case rally = "rally"

    /// The interval in completed points, `nil` for rally serve.
    var interval: Int? {
        switch self {
        case .every2: return 2
        case .every5: return 5
        case .rally:  return nil
        }
    }

    var displayName: String {
        switch self {
        case .every2: return String(localized: "Every 2 points")
        case .every5: return String(localized: "Every 5 points")
        case .rally:  return String(localized: "Rally serve")
        }
    }
}

/// The ping pong rules a match is played under.
///
/// Three knobs — points per set, best-of, serve mode. Win-by-2 is a fixed rule,
/// not a knob. A `PingPongRuleset` is stamped by value onto a match at its
/// start (via the enclosing `Ruleset`, ADR 0006), so editing or renaming it
/// later never rewrites a match already played.
struct PingPongRuleset: Codable, Equatable, Sendable, Identifiable {
    enum CodingVersion: String, Codable {
        case v1
    }

    /// The allowed "Melhor de" values.
    static let validBestOf = [1, 3, 5, 7]

    private let codingVersion: CodingVersion
    var identifier: UUID
    var name: String
    let pointsTarget: Int
    let bestOf: Int
    let serveMode: PingPongServeMode
    /// Fixed, not a knob. Kept on the value so the stamped match carries the
    /// rule it was actually played under even if the rule ever becomes a knob.
    let winByTwo: Bool

    init(
        codingVersion: CodingVersion = .v1,
        identifier: UUID,
        name: String,
        pointsTarget: Int,
        bestOf: Int,
        serveMode: PingPongServeMode,
        winByTwo: Bool = true
    ) {
        self.codingVersion = codingVersion
        self.identifier = identifier
        self.name = name
        self.pointsTarget = pointsTarget
        self.bestOf = bestOf
        self.serveMode = serveMode
        self.winByTwo = winByTwo
    }

    /// Identifiable identity is the ruleset's stable identity.
    var id: UUID { identifier }

    /// Matches won by winning this many games.
    var gamesToWinMatch: Int { (bestOf + 1) / 2 }

    /// Whether the value is a playable ruleset: positive points target (any
    /// positive value, no arbitrary cap), best-of one of 1/3/5/7, and an
    /// arithmetic-safe deuce bound — `2×(target−1)` must not overflow. Win-By-2
    /// is always on.
    var isValid: Bool {
        guard winByTwo else { return false }
        guard pointsTarget >= 1 else { return false }
        guard Self.validBestOf.contains(bestOf) else { return false }
        // The deuce bound `2×(target−1)` overflows once `target−1 > Int.max/2`.
        // Checked before the multiply so an absurd target decodes to "invalid"
        // instead of trapping in the arithmetic.
        return pointsTarget - 1 <= Int.max / 2
    }

    // MARK: - Codable (validating)

    private enum CodingKeys: String, CodingKey {
        case codingVersion, identifier, name, pointsTarget, bestOf, serveMode, winByTwo
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        codingVersion = try c.decodeIfPresent(CodingVersion.self, forKey: .codingVersion) ?? .v1
        identifier = try c.decode(UUID.self, forKey: .identifier)
        name = try c.decode(String.self, forKey: .name)
        pointsTarget = try c.decode(Int.self, forKey: .pointsTarget)
        bestOf = try c.decode(Int.self, forKey: .bestOf)
        serveMode = try c.decode(PingPongServeMode.self, forKey: .serveMode)
        winByTwo = try c.decodeIfPresent(Bool.self, forKey: .winByTwo) ?? true
        guard isValid else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Malformed ping pong ruleset"
            ))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(codingVersion, forKey: .codingVersion)
        try c.encode(identifier, forKey: .identifier)
        try c.encode(name, forKey: .name)
        try c.encode(pointsTarget, forKey: .pointsTarget)
        try c.encode(bestOf, forKey: .bestOf)
        try c.encode(serveMode, forKey: .serveMode)
        try c.encode(winByTwo, forKey: .winByTwo)
    }
}

// MARK: - Presets

extension PingPongRuleset {
    /// Stable preset identifiers, shipped and never renamed. A match stamped
    /// with a preset keeps this identifier forever; the library finds the preset
    /// by identity, never by name or knobs.
    static let oficialID = UUID(uuidString: "8F3E2A1C-5D4B-47F0-9E1A-000000000001")!
    static let classicoID = UUID(uuidString: "8F3E2A1C-5D4B-47F0-9E1A-000000000002")!
    static let rapidoID = UUID(uuidString: "8F3E2A1C-5D4B-47F0-9E1A-000000000003")!

    /// **Oficial** — 11 points, best of 5, serve every 2. The factory default.
    static let oficial = PingPongRuleset(
        identifier: oficialID,
        name: String(localized: "Ping Pong Official"),
        pointsTarget: 11,
        bestOf: 5,
        serveMode: .every2
    )

    /// **Clássico** — 21 points, best of 3, serve every 5.
    static let classico = PingPongRuleset(
        identifier: classicoID,
        name: String(localized: "Ping Pong Classic"),
        pointsTarget: 21,
        bestOf: 3,
        serveMode: .every5
    )

    /// **Rápido** — 11 points, best of 1, serve every 2.
    static let rapido = PingPongRuleset(
        identifier: rapidoID,
        name: String(localized: "Ping Pong Quick"),
        pointsTarget: 11,
        bestOf: 1,
        serveMode: .every2
    )

    static let presets: [PingPongRuleset] = [.oficial, .classico, .rapido]

    var isPreset: Bool {
        Self.presets.contains { $0.identifier == identifier }
    }
}

/// The authoritative ping pong scoring state (ADR 0005).
///
/// Ping pong owns its integer points, its games won and its initial-server
/// inputs here — nothing is mirrored into the legacy beach/tennis scoring
/// fields (`PointScore`, `setsWon`, tiebreak counters). The flat
/// `MatchState.setScoreA/B` columns are a *projection* of `gamesWonA/B` for the
/// wire and storage formats, per ADR 0005: a stored ping match's `setScoreA/B`
/// is its games-won count despite the column name.
struct PingPongState: Codable, Sendable, Equatable {
    var pointsA: Int = 0
    var pointsB: Int = 0
    var gamesWonA: Int = 0
    var gamesWonB: Int = 0
    /// The serve chosen before the match's first rally.
    var initialServer: Team
    /// Who serves first in the current game. Alternates between games,
    /// independently of who served the preceding game's last point.
    var gameInitialServer: Team

    /// A brand-new match's state. Both the match's remembered `initialServer`
    /// and the first game's server start from `serveChoice` — the first game
    /// always opens with the serve the player picked.
    init(initialServer: Team) {
        self.initialServer = initialServer
        self.gameInitialServer = initialServer
    }
}