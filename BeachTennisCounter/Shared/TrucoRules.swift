import Foundation

/// The truco rules a match is played under (CONTEXT.md "Stake").
///
/// Three knobs — the target (**Pontos para vencer**), the base Valor of an
/// uncontested Mão, and the raise ladder it climbs once someone calls truco.
/// Stamped by value onto a match at its start via the enclosing `Ruleset`
/// (ADR 0006), so editing or renaming it later never rewrites a match played.
struct TrucoRuleset: Codable, Equatable, Sendable, Identifiable {
    enum CodingVersion: String, Codable {
        case v1
    }

    /// The base Valor is a closed menu: "conta de 2 em 2" is the only variant.
    static let validBaseValues = [1, 2]
    /// The crown strip on a 40mm watch fits base + 4 cells before a two-digit
    /// Valor starts to clip (#141), so a ladder has 1 to 4 raises.
    static let maxRaises = 4

    private let codingVersion: CodingVersion
    var identifier: UUID
    var name: String
    let pointsTarget: Int
    let baseValue: Int
    let raises: [Int]

    init(
        codingVersion: CodingVersion = .v1,
        identifier: UUID,
        name: String,
        pointsTarget: Int,
        baseValue: Int,
        raises: [Int]
    ) {
        self.codingVersion = codingVersion
        self.identifier = identifier
        self.name = name
        self.pointsTarget = pointsTarget
        self.baseValue = baseValue
        self.raises = raises
    }

    var id: UUID { identifier }

    /// Every Valor a Mão can be worth, cheapest first — the crown strip's cells.
    var stakes: [Int] { [baseValue] + raises }

    /// Positive target, base 1 or 2, and a ladder of 1–4 raises that is
    /// strictly increasing from above the base: turning the crown right always
    /// means "worth more".
    static func isValidLadder(_ raises: [Int], base: Int) -> Bool {
        guard (1...maxRaises).contains(raises.count) else { return false }
        return zip([base] + raises, raises).allSatisfy { $0 < $1 }
    }

    var isValid: Bool {
        pointsTarget >= 1
            && Self.validBaseValues.contains(baseValue)
            && Self.isValidLadder(raises, base: baseValue)
    }

    // MARK: - Codable (validating)

    private enum CodingKeys: String, CodingKey {
        case codingVersion, identifier, name, pointsTarget, baseValue, raises
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        codingVersion = try c.decodeIfPresent(CodingVersion.self, forKey: .codingVersion) ?? .v1
        identifier = try c.decode(UUID.self, forKey: .identifier)
        name = try c.decode(String.self, forKey: .name)
        pointsTarget = try c.decode(Int.self, forKey: .pointsTarget)
        baseValue = try c.decode(Int.self, forKey: .baseValue)
        raises = try c.decode([Int].self, forKey: .raises)
        guard isValid else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Malformed truco ruleset"
            ))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(codingVersion, forKey: .codingVersion)
        try c.encode(identifier, forKey: .identifier)
        try c.encode(name, forKey: .name)
        try c.encode(pointsTarget, forKey: .pointsTarget)
        try c.encode(baseValue, forKey: .baseValue)
        try c.encode(raises, forKey: .raises)
    }

    /// A copy with the given knobs replaced — fields are immutable (ADR 0006
    /// stamping), so an edit builds a new value.
    func with(pointsTarget: Int? = nil, baseValue: Int? = nil, raises: [Int]? = nil) -> TrucoRuleset {
        TrucoRuleset(
            identifier: identifier,
            name: name,
            pointsTarget: pointsTarget ?? self.pointsTarget,
            baseValue: baseValue ?? self.baseValue,
            raises: raises ?? self.raises
        )
    }
}

// MARK: - Presets

extension TrucoRuleset {
    /// Stable preset identifiers, shipped and never renamed.
    static let paulistaID = UUID(uuidString: "3B1C7E40-2A9D-4C5E-8F11-000000000001")!
    static let mineiroID = UUID(uuidString: "3B1C7E40-2A9D-4C5E-8F11-000000000002")!
    static let gauderioID = UUID(uuidString: "3B1C7E40-2A9D-4C5E-8F11-000000000003")!

    /// **Paulista** — 12 points, base 1, 3·6·9·12. The factory default.
    static let paulista = TrucoRuleset(
        identifier: paulistaID,
        name: String(localized: "Truco Paulista"),
        pointsTarget: 12,
        baseValue: 1,
        raises: [3, 6, 9, 12]
    )

    /// **Mineiro** — 12 points, base 2, 4·6·10·12.
    static let mineiro = TrucoRuleset(
        identifier: mineiroID,
        name: String(localized: "Truco Mineiro"),
        pointsTarget: 12,
        baseValue: 2,
        raises: [4, 6, 10, 12]
    )

    /// **Gaudério** — 24 points, base 1, 2·3·4.
    static let gauderio = TrucoRuleset(
        identifier: gauderioID,
        name: String(localized: "Truco Gaudério"),
        pointsTarget: 24,
        baseValue: 1,
        raises: [2, 3, 4]
    )

    static let presets: [TrucoRuleset] = [.paulista, .mineiro, .gauderio]

    var isPreset: Bool {
        Self.presets.contains { $0.identifier == identifier }
    }
}
