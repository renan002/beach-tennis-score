import Foundation

/// How a beach tennis match ends (CONTEXT.md: Match Format). The raw values are
/// storage keys, never localized and never renamed.
enum BeachMatchFormat: String, Codable, CaseIterable, Sendable {
    /// Primeiro a N — the first side to N Sets wins.
    case firstTo = "firstTo"
    /// Sempre N — exactly N Sets are always played; more Sets wins.
    case always = "always"

    var displayName: String {
        switch self {
        case .firstTo: return String(localized: "First to")
        case .always:  return String(localized: "Always")
        }
    }
}

/// What happens at 40–40 in a beach game (CONTEXT.md: Deuce Rule). Raw values
/// are storage keys.
enum BeachDeuceRule: String, Codable, CaseIterable, Sendable {
    case goldenPoint = "goldenPoint"
    case advantage = "advantage"

    var displayName: String {
        switch self {
        case .goldenPoint: return String(localized: "Golden point")
        case .advantage:   return String(localized: "Advantage")
        }
    }
}

/// The beach tennis rules a match is played under, stamped by value onto the
/// match through the enclosing `Ruleset` (ADR 0006).
struct BeachTennisRuleset: Codable, Equatable, Sendable, Identifiable {
    enum CodingVersion: String, Codable {
        case v1
    }

    static let validSets = 1...15
    static let validTiebreakPoints = 5...21

    private let codingVersion: CodingVersion
    var identifier: UUID
    var name: String
    let format: BeachMatchFormat
    /// N — the Sets raced to, or always played.
    let sets: Int
    /// Primeiro a N only: a side must lead by two Sets to win.
    let winByTwoSets: Bool
    /// Whether a level match is decided by a Tiebreak — at N–N in Primeiro a N
    /// (only reachable with `winByTwoSets`), or on an even N's tie in Sempre N.
    let tiebreak: Bool
    let tiebreakPoints: Int
    let tiebreakWinByTwo: Bool
    let deuceRule: BeachDeuceRule

    init(
        codingVersion: CodingVersion = .v1,
        identifier: UUID,
        name: String,
        format: BeachMatchFormat,
        sets: Int,
        winByTwoSets: Bool,
        tiebreak: Bool,
        tiebreakPoints: Int,
        tiebreakWinByTwo: Bool,
        deuceRule: BeachDeuceRule
    ) {
        self.codingVersion = codingVersion
        self.identifier = identifier
        self.name = name
        self.format = format
        self.sets = sets
        self.winByTwoSets = winByTwoSets
        self.tiebreak = tiebreak
        self.tiebreakPoints = tiebreakPoints
        self.tiebreakWinByTwo = tiebreakWinByTwo
        self.deuceRule = deuceRule
    }

    var id: UUID { identifier }

    /// A match never ends drawn, so Sempre N with an even N needs its Tiebreak.
    /// A Tiebreak that can never trigger (Primeiro a N without win-by-two) is
    /// harmless, not invalid.
    var isValid: Bool {
        Self.validSets.contains(sets)
            && Self.validTiebreakPoints.contains(tiebreakPoints)
            && !(requiresTiebreak && !tiebreak)
    }

    /// Sempre N with an even N can end level, and a match never ends drawn.
    var requiresTiebreak: Bool { format == .always && sets % 2 == 0 }

    /// Whether the Tiebreak knob can matter under the other knobs.
    var tiebreakCanTrigger: Bool {
        format == .firstTo ? winByTwoSets : requiresTiebreak
    }

    /// Copy with one knob changed — the Rules editor's only way to edit.
    func with(
        format: BeachMatchFormat? = nil,
        sets: Int? = nil,
        winByTwoSets: Bool? = nil,
        tiebreak: Bool? = nil,
        tiebreakPoints: Int? = nil,
        tiebreakWinByTwo: Bool? = nil,
        deuceRule: BeachDeuceRule? = nil
    ) -> BeachTennisRuleset {
        BeachTennisRuleset(
            identifier: identifier,
            name: name,
            format: format ?? self.format,
            sets: sets ?? self.sets,
            winByTwoSets: winByTwoSets ?? self.winByTwoSets,
            tiebreak: tiebreak ?? self.tiebreak,
            tiebreakPoints: tiebreakPoints ?? self.tiebreakPoints,
            tiebreakWinByTwo: tiebreakWinByTwo ?? self.tiebreakWinByTwo,
            deuceRule: deuceRule ?? self.deuceRule
        )
    }

    // MARK: - Codable (validating)

    private enum CodingKeys: String, CodingKey {
        case codingVersion, identifier, name, format, sets, winByTwoSets
        case tiebreak, tiebreakPoints, tiebreakWinByTwo, deuceRule
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        codingVersion = try c.decodeIfPresent(CodingVersion.self, forKey: .codingVersion) ?? .v1
        identifier = try c.decode(UUID.self, forKey: .identifier)
        name = try c.decode(String.self, forKey: .name)
        format = try c.decode(BeachMatchFormat.self, forKey: .format)
        sets = try c.decode(Int.self, forKey: .sets)
        winByTwoSets = try c.decode(Bool.self, forKey: .winByTwoSets)
        tiebreak = try c.decode(Bool.self, forKey: .tiebreak)
        tiebreakPoints = try c.decode(Int.self, forKey: .tiebreakPoints)
        tiebreakWinByTwo = try c.decode(Bool.self, forKey: .tiebreakWinByTwo)
        deuceRule = try c.decode(BeachDeuceRule.self, forKey: .deuceRule)
        guard isValid else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Malformed beach tennis ruleset"
            ))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(codingVersion, forKey: .codingVersion)
        try c.encode(identifier, forKey: .identifier)
        try c.encode(name, forKey: .name)
        try c.encode(format, forKey: .format)
        try c.encode(sets, forKey: .sets)
        try c.encode(winByTwoSets, forKey: .winByTwoSets)
        try c.encode(tiebreak, forKey: .tiebreak)
        try c.encode(tiebreakPoints, forKey: .tiebreakPoints)
        try c.encode(tiebreakWinByTwo, forKey: .tiebreakWinByTwo)
        try c.encode(deuceRule, forKey: .deuceRule)
    }
}

// MARK: - Presets

extension BeachTennisRuleset {
    /// The beach preset's identity since before Rulesets were editable — kept,
    /// so every beach match already played is recognised as Padrão.
    static let padraoID = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!

    /// **Padrão** — Primeiro a 6, win by two, Tiebreak at 6–6 to 7 win by two,
    /// Ponto de ouro. Exactly how beach was scored before rules were editable.
    static let padrao = BeachTennisRuleset(
        identifier: padraoID,
        name: String(localized: "Standard"),
        format: .firstTo,
        sets: 6,
        winByTwoSets: true,
        tiebreak: true,
        tiebreakPoints: 7,
        tiebreakWinByTwo: true,
        deuceRule: .goldenPoint
    )

    static let presets: [BeachTennisRuleset] = [.padrao]

    var isPreset: Bool {
        Self.presets.contains { $0.identifier == identifier }
    }
}
