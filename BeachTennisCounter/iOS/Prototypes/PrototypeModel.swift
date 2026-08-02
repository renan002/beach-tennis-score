import SwiftUI

// PROTOTYPE — throwaway. Issue #126. Do not promote any of this to production.
//
// Gated on `DEV_FLAVOR` so it cannot exist in a Debug or Release build, same as
// Dev Tools. Copy here is deliberately NOT in the String Catalog — the copy is
// part of what is being judged, so it is written in pt-BR inline where a reader
// can edit it and re-run in seconds.

#if DEV_FLAVOR

// MARK: - Throwaway domain

/// All four sports of #61, in the order the app would list them — including the
/// two whose Rulesets are **frozen**. Prototyping the sport axis with only the
/// two editable sports is what hid the problem the first time round.
enum ProtoSport: String, CaseIterable, Identifiable {
    case beachTennis = "Beach Tennis"
    case tennis = "Tennis"
    case pingPong = "Ping pong"
    case truco = "Truco"

    var id: String { rawValue }

    /// Beach tennis and tennis ship frozen built-in Rulesets that reproduce
    /// today's behaviour exactly (#61). They have Regras — they just have
    /// nothing to change.
    var isEditable: Bool {
        switch self {
        case .beachTennis, .tennis: return false
        case .pingPong, .truco: return true
        }
    }

    static var editable: [ProtoSport] { allCases.filter(\.isEditable) }

    var icon: String {
        switch self {
        case .beachTennis: return "beach.umbrella"
        case .tennis: return "figure.tennis"
        case .pingPong: return "figure.table.tennis"
        case .truco: return "suit.spade.fill"
        }
    }
}

enum ProtoServe: String, CaseIterable, Identifiable {
    case every2 = "A cada 2"
    case every5 = "A cada 5"
    case rally = "Quem fez o ponto"

    var id: String { rawValue }
}

/// One Ruleset, both sports' knobs in one bag. Production splits this per sport
/// (ADR 0005); the prototype does not care.
struct ProtoRuleset: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var isPreset: Bool = false

    // Ping pong (issue #125)
    var pointsPerSet: Int = 11
    var bestOf: Int = 5
    var serve: ProtoServe = .every2

    // Truco (issue #124)
    var target: Int = 12
    var base: Int = 1
    var ladder: [Int] = [3, 6, 9, 12]

    /// The Ruleset as one sentence — used verbatim by Variant C, and as the
    /// summary line by Variant B.
    func summary(_ sport: ProtoSport) -> String {
        switch sport {
        case .beachTennis:
            return "6 sets · ponto de ouro no 40-40 · super tiebreak no 6-6"
        case .tennis:
            return "melhor de 3 sets · tiebreak no 6-6"
        case .pingPong:
            return "\(pointsPerSet) pontos · melhor de \(bestOf) · saque \(serve.rawValue.lowercased())"
        case .truco:
            return "\(target) pontos · mão vale \(base) · escalada \(ladder.map(String.init).joined(separator: "·"))"
        }
    }

    /// The ladders the shipped Presets use — the closed-ladder answer to #141.
    static let knownLadders: [[Int]] = [[3, 6, 9, 12], [4, 6, 10, 12], [2, 3, 4]]

    static func presets(_ sport: ProtoSport) -> [ProtoRuleset] {
        switch sport {
        case .beachTennis:
            return [ProtoRuleset(name: "Padrão", isPreset: true)]
        case .tennis:
            return [ProtoRuleset(name: "Padrão", isPreset: true)]
        case .pingPong:
            return [
                ProtoRuleset(name: "Oficial", isPreset: true, pointsPerSet: 11, bestOf: 5, serve: .every2),
                ProtoRuleset(name: "Clássico", isPreset: true, pointsPerSet: 21, bestOf: 3, serve: .every5),
                ProtoRuleset(name: "Rápido", isPreset: true, pointsPerSet: 11, bestOf: 1, serve: .every2),
            ]
        case .truco:
            return [
                ProtoRuleset(name: "Paulista", isPreset: true, target: 12, base: 1, ladder: [3, 6, 9, 12]),
                ProtoRuleset(name: "Mineiro", isPreset: true, target: 12, base: 2, ladder: [4, 6, 10, 12]),
                ProtoRuleset(name: "Gaudério", isPreset: true, target: 24, base: 1, ladder: [2, 3, 4]),
            ]
        }
    }

    /// Two saved Custom Rulesets so the list is never judged empty — an empty
    /// library hides exactly the density question #126 asks.
    static func customs(_ sport: ProtoSport) -> [ProtoRuleset] {
        switch sport {
        case .beachTennis, .tennis:
            return []
        case .pingPong:
            return [ProtoRuleset(name: "Escritório", pointsPerSet: 21, bestOf: 1, serve: .rally)]
        case .truco:
            return [
                ProtoRuleset(name: "Truco do Zé", target: 12, base: 1, ladder: [3, 6, 9, 12]),
                ProtoRuleset(name: "Churrasco da firma", target: 24, base: 2, ladder: [4, 8, 12, 24]),
            ]
        }
    }

    /// Knob equality — ignores name and id, so an edited Preset reads as
    /// "Personalizado" the moment a knob moves.
    func sameKnobs(as other: ProtoRuleset, _ sport: ProtoSport) -> Bool {
        switch sport {
        case .beachTennis, .tennis:
            return true
        case .pingPong:
            return pointsPerSet == other.pointsPerSet && bestOf == other.bestOf && serve == other.serve
        case .truco:
            return target == other.target && base == other.base && ladder == other.ladder
        }
    }
}

/// One sport's library. In-memory, no persistence (prototype rule 3).
///
/// The sport is fixed at init: each sport keeps its **own** active Ruleset, and
/// a library that could change sport under you was hiding that. #61 syncs the
/// active Ruleset of every sport to the watch, so per-sport state is the real
/// shape, not a prototype convenience.
@Observable
final class ProtoLibrary {
    let sport: ProtoSport
    var draft: ProtoRuleset
    var saved: [ProtoRuleset]
    // Stored, not computed: `ProtoRuleset.presets(_:)` mints fresh ids on every
    // call, so identity only survives if the list is built once.
    private var presetList: [ProtoRuleset]

    init(sport: ProtoSport) {
        self.sport = sport
        let initial = ProtoRuleset.presets(sport)
        presetList = initial
        saved = ProtoRuleset.customs(sport)
        draft = initial[0]
        appliedID = initial[0].id
    }

    /// Which Ruleset was last applied. Selection by knob equality alone cannot
    /// tell a saved copy from the Preset it was copied from — the double
    /// checkmark seen in Variant A — so identity is tracked separately.
    var appliedID: UUID?

    var presets: [ProtoRuleset] { presetList }

    var all: [ProtoRuleset] { presetList + saved }

    /// The Ruleset the draft still *is*: the applied one, and only while its
    /// knobs have not moved. Nil means Personalizado.
    var applied: ProtoRuleset? {
        guard let match = all.first(where: { $0.id == appliedID }) else { return nil }
        return match.sameKnobs(as: draft, sport) ? match : nil
    }

    /// The name to show for the current draft: a Preset's name while its knobs
    /// are untouched, otherwise "Personalizado".
    var draftLabel: String { applied?.name ?? "Personalizado" }

    var isDirty: Bool { applied == nil }

    func apply(_ ruleset: ProtoRuleset) {
        draft = ruleset
        appliedID = ruleset.id
    }

    func save(as name: String) {
        var copy = draft
        copy.id = UUID()
        copy.name = name
        copy.isPreset = false
        saved.append(copy)
        appliedID = copy.id
    }

    func delete(_ ruleset: ProtoRuleset) {
        saved.removeAll { $0.id == ruleset.id }
    }
}

/// Every sport's library at once — what the Regras screen actually sits on,
/// whichever shell wins.
@Observable
final class ProtoRegrasStore {
    private var libraries: [String: ProtoLibrary] = [:]

    init() {
        for sport in ProtoSport.allCases {
            libraries[sport.id] = ProtoLibrary(sport: sport)
        }
    }

    func library(_ sport: ProtoSport) -> ProtoLibrary {
        libraries[sport.id]!
    }
}

// MARK: - Switcher

/// The floating variant bar. Deliberately ugly — high-contrast, pinned, clearly
/// not part of any design being judged.
struct ProtoSwitcher: View {
    let names: [String]
    @Binding var index: Int

    var body: some View {
        HStack(spacing: 14) {
            Button { index = (index - 1 + names.count) % names.count } label: {
                Image(systemName: "chevron.left")
            }
            Text(names[index])
                .font(.footnote.weight(.semibold).monospaced())
                .lineLimit(1)
            Button { index = (index + 1) % names.count } label: {
                Image(systemName: "chevron.right")
            }
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(.yellow).shadow(radius: 8))
        .buttonStyle(.plain)
    }
}

#endif
