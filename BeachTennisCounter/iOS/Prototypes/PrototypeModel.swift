import SwiftUI

// PROTOTYPE — throwaway. Issue #126. Do not promote any of this to production.
//
// Gated on `DEV_FLAVOR` so it cannot exist in a Debug or Release build, same as
// Dev Tools. Copy here is deliberately NOT in the String Catalog — the copy is
// part of what is being judged, so it is written in pt-BR inline where a reader
// can edit it and re-run in seconds.

#if DEV_FLAVOR

// MARK: - Throwaway domain

enum ProtoSport: String, CaseIterable, Identifiable {
    case pingPong = "Ping pong"
    case truco = "Truco"

    var id: String { rawValue }
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
        case .pingPong:
            return "\(pointsPerSet) pontos · melhor de \(bestOf) · saque \(serve.rawValue.lowercased())"
        case .truco:
            return "\(target) pontos · mão vale \(base) · escalada \(ladder.map(String.init).joined(separator: "·"))"
        }
    }

    static func presets(_ sport: ProtoSport) -> [ProtoRuleset] {
        switch sport {
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
        case .pingPong:
            return pointsPerSet == other.pointsPerSet && bestOf == other.bestOf && serve == other.serve
        case .truco:
            return target == other.target && base == other.base && ladder == other.ladder
        }
    }
}

/// Shared, in-memory library. No persistence, on purpose (prototype rule 3).
@Observable
final class ProtoLibrary {
    var sport: ProtoSport = .truco
    var draft: ProtoRuleset = ProtoRuleset.presets(.truco)[0]
    var saved: [ProtoRuleset] = ProtoRuleset.customs(.truco)

    var presets: [ProtoRuleset] { ProtoRuleset.presets(sport) }

    /// The name to show for the current draft: a Preset's name while its knobs
    /// are untouched, otherwise "Personalizado".
    var draftLabel: String {
        if let match = (presets + saved).first(where: { $0.sameKnobs(as: draft, sport) }) {
            return match.name
        }
        return "Personalizado"
    }

    var isDirty: Bool { draftLabel == "Personalizado" }

    func switchSport(_ new: ProtoSport) {
        sport = new
        draft = ProtoRuleset.presets(new)[0]
        saved = ProtoRuleset.customs(new)
    }

    func apply(_ ruleset: ProtoRuleset) {
        var copy = ruleset
        copy.id = UUID()
        draft = copy
    }

    func save(as name: String) {
        var copy = draft
        copy.id = UUID()
        copy.name = name
        copy.isPreset = false
        saved.append(copy)
    }

    func delete(_ ruleset: ProtoRuleset) {
        saved.removeAll { $0.id == ruleset.id }
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
            Text("\(letter) — \(names[index])")
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

    private var letter: String {
        String(UnicodeScalar(UInt8(65 + index)))
    }
}

#endif
