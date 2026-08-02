import SwiftUI

// PROTOTYPE — throwaway. Issue #126, question 3: "O placar de truco no iPhone
// se parece com quê?" No serve, no workout, two big numbers on a big screen.
//
//   A — Mesa: screen split in half, opponent's half rotated 180°, tap anywhere.
//   B — Placar: two columns side by side, value chosen first on a standing bar.
//   C — Caderno: small scores, the Game Log is the screen, entries editable.

#if DEV_FLAVOR

struct ProtoManche: Identifiable {
    let id = UUID()
    var team: Int   // 0 = Nós, 1 = Eles
    var value: Int
}

@Observable
final class ProtoTrucoMatch {
    var ruleset: ProtoRuleset = ProtoRuleset.presets(.truco)[0]
    var log: [ProtoManche] = []

    var names = ["Nós", "Eles"]

    func score(_ team: Int) -> Int {
        log.filter { $0.team == team }.reduce(0) { $0 + $1.value }
    }

    var winner: Int? {
        for team in 0...1 where score(team) >= ruleset.target { return team }
        return nil
    }

    func add(_ team: Int, _ value: Int) {
        log.append(ProtoManche(team: team, value: value))
    }

    func undo() { if !log.isEmpty { log.removeLast() } }

    func reset() { log.removeAll() }

    /// Base first, then the ladder — the values the tap and the picker offer.
    var values: [Int] { [ruleset.base] + ruleset.ladder }
}

// MARK: - A — Mesa

/// The phone lies flat between the two pairs. Each half belongs to one side and
/// is one enormous tap target; the far half is upside down so the players
/// across the table read their own score right way up.
struct ProtoPlacarA: View {
    @Bindable var match: ProtoTrucoMatch
    @State private var pickerTeam: Int?

    var body: some View {
        VStack(spacing: 2) {
            half(team: 1).rotationEffect(.degrees(180))
            half(team: 0)
        }
        .overlay(alignment: .center) { centerBar }
        .confirmationDialog(
            "Valor da mão",
            isPresented: Binding(get: { pickerTeam != nil }, set: { if !$0 { pickerTeam = nil } }),
            titleVisibility: .visible
        ) {
            ForEach(match.values, id: \.self) { value in
                Button("\(value)") {
                    if let team = pickerTeam { match.add(team, value) }
                    pickerTeam = nil
                }
            }
            Button("Cancelar", role: .cancel) { pickerTeam = nil }
        }
    }

    private func half(team: Int) -> some View {
        ZStack {
            (team == 0 ? Color.blue : Color.red).opacity(0.85)
            VStack(spacing: 4) {
                Text(match.names[team])
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text("\(match.score(team))")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        }
        .contentShape(.rect)
        .onTapGesture { withAnimation { match.add(team, match.ruleset.base) } }
        .onLongPressGesture(minimumDuration: 0.4) { pickerTeam = team }
    }

    /// Thin strip on the seam: the only chrome, reachable from either side.
    private var centerBar: some View {
        HStack(spacing: 20) {
            Button { match.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(match.log.isEmpty)
            Text("até \(match.ruleset.target)")
                .font(.caption.monospacedDigit())
            Button { match.reset() } label: { Image(systemName: "arrow.counterclockwise") }
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Capsule().fill(.black.opacity(0.75)))
    }
}

// MARK: - B — Placar

/// A scoreboard read from one side, with no hidden gestures at all: the value
/// of the mão is a standing segmented bar you set first, then you tap a team.
struct ProtoPlacarB: View {
    @Bindable var match: ProtoTrucoMatch
    @State private var pending: Int = 1

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                column(team: 0, color: .blue)
                column(team: 1, color: .red)
            }

            VStack(spacing: 12) {
                Text("Valor da mão")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(match.values, id: \.self) { value in
                        Button {
                            pending = value
                        } label: {
                            Text("\(value)")
                                .font(.title2.weight(.bold).monospacedDigit())
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(pending == value ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                                )
                                .foregroundStyle(pending == value ? .white : .primary)
                        }
                    }
                }

                HStack {
                    Button("Desfazer") { match.undo() }
                        .disabled(match.log.isEmpty)
                    Spacer()
                    Text("Jogo até \(match.ruleset.target)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Zerar") { match.reset() }
                }
                .font(.footnote)
            }
            .padding()
            .background(.thinMaterial)
        }
        .onAppear { pending = match.ruleset.base }
    }

    private func column(team: Int, color: Color) -> some View {
        Button {
            withAnimation { match.add(team, pending) }
            pending = match.ruleset.base
        } label: {
            VStack(spacing: 6) {
                Text(match.names[team])
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("\(match.score(team))")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(color.opacity(0.85))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - C — Caderno

/// The paper napkin: the running list of mãos is the screen, and the totals are
/// a header. Built for the argument that actually happens — "quem fez aquela de
/// seis?" — so every entry stays editable after the fact.
struct ProtoPlacarC: View {
    @Bindable var match: ProtoTrucoMatch

    var body: some View {
        VStack(spacing: 0) {
            header

            List {
                ForEach(Array(match.log.enumerated().reversed()), id: \.element.id) { index, manche in
                    HStack {
                        Text("Mão \(index + 1)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(match.names[manche.team])
                            .font(.body.weight(.medium))
                            .foregroundStyle(manche.team == 0 ? .blue : .red)
                        Menu("\(manche.value)") {
                            ForEach(match.values, id: \.self) { value in
                                Button("\(value)") { match.log[index].value = value }
                            }
                        }
                        .font(.body.weight(.bold).monospacedDigit())
                        .frame(width: 44)
                    }
                }
                .onDelete { offsets in
                    // The list is reversed; map back before deleting.
                    let real = offsets.map { match.log.count - 1 - $0 }
                    for i in real.sorted(by: >) { match.log.remove(at: i) }
                }
            }
            .listStyle(.plain)
            .overlay {
                if match.log.isEmpty {
                    ContentUnavailableView("Nenhuma mão", systemImage: "list.bullet", description: Text("Toque numa dupla abaixo."))
                }
            }

            HStack(spacing: 10) {
                addButton(team: 0, color: .blue)
                addButton(team: 1, color: .red)
            }
            .padding()
            .background(.thinMaterial)
        }
    }

    private var header: some View {
        HStack {
            total(team: 0, color: .blue)
            Text("×").font(.title2).foregroundStyle(.secondary)
            total(team: 1, color: .red)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Text("Jogo até \(match.ruleset.target)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
        }
    }

    private func total(team: Int, color: Color) -> some View {
        VStack(spacing: 0) {
            Text(match.names[team]).font(.caption).foregroundStyle(.secondary)
            Text("\(match.score(team))")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    /// Tap credits the base value straight away — the common case never waits.
    /// Long press offers the ladder, and any entry can be fixed in the list.
    private func addButton(team: Int, color: Color) -> some View {
        Menu {
            ForEach(match.values, id: \.self) { value in
                Button("\(value) ponto\(value == 1 ? "" : "s")") { match.add(team, value) }
            }
        } label: {
            Text(match.names[team])
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.9)))
                .foregroundStyle(.white)
        } primaryAction: {
            withAnimation { match.add(team, match.ruleset.base) }
        }
    }
}

#endif
