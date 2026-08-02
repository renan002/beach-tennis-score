import SwiftUI
import WatchKit

// PROTOTYPE — throwaway. Issue #126, question 2: "Toque longo para o valor da
// mão funciona no pulso?"
//
// Three ways to enter a mão worth more than the base value. All three keep the
// same skeleton as the real ScoreView — black, two squares, undo at top-left —
// so the gesture is judged, not the layout.
//
//   A — Toque = +1, toque longo = seletor. The design #61 proposes.
//   B — Coroa digital escolhe o valor, toque credita. No long press at all.
//   C — Toque = +1 sempre; a última entrada vira um chip promovível.
//
// Run this ON THE WRIST, wrong hand, arm moving. The simulator cannot answer
// this question; it can only show that the views draw.

#if DEV_FLAVOR

private let names = ["Nós", "Eles"]
private let ladder = [1, 3, 6, 9, 12]
private let target = 12

@Observable
final class ProtoStakeMatch {
    var entries: [(team: Int, value: Int)] = []

    func score(_ team: Int) -> Int {
        entries.filter { $0.team == team }.reduce(0) { $0 + $1.value }
    }

    /// `target` was only ever drawn in the top bar — nothing enforced it, so the
    /// score sailed past 12. Same bug the iPhone placar had, same fix: derived
    /// from the score, so correcting a mão down un-finishes the match.
    var winner: Int? {
        for team in 0...1 where score(team) >= target { return team }
        return nil
    }

    func add(_ team: Int, _ value: Int) {
        guard winner == nil else { return }
        entries.append((team, value))
        WKInterfaceDevice.current().play(value == 1 ? .click : .success)
        if winner != nil { WKInterfaceDevice.current().play(.notification) }
    }

    func undo() { if !entries.isEmpty { entries.removeLast() } }
    func reset() { entries.removeAll() }
}

/// The shared skeleton: score row, two tappable squares, top bar.
private struct ProtoStakeChrome<Square: View, Extra: View>: View {
    @Bindable var match: ProtoStakeMatch
    let hint: String
    @ViewBuilder let square: (Int) -> Square
    @ViewBuilder let extra: () -> Extra

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 4) {
                HStack {
                    Button { match.undo() } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(match.entries.isEmpty ? .gray : .white)
                    }
                    .buttonStyle(.plain)
                    .disabled(match.entries.isEmpty)
                    Spacer()
                    Text("até \(target)")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }

                HStack {
                    Text("\(match.score(0))")
                        .foregroundStyle(.blue)
                    Spacer()
                    Text("\(match.score(1))")
                        .foregroundStyle(.red)
                }
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .contentTransition(.numericText())

                extra()

                HStack(spacing: 6) {
                    square(0)
                    square(1)
                }

                Text(hint)
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 6)
            .overlay {
                if match.winner != nil { matchOver }
            }
        }
        // The nav bar stays: hiding it, the way the real ScoreView does, also
        // takes the back chevron with it and strands you in the variant. The
        // real screen can afford that because it has its own exit; a prototype
        // you are meant to flip through cannot.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The real ScoreView's match-over card, shrunk: it covers the squares, so
    /// a stray tap after the last mão cannot score.
    private var matchOver: some View {
        let winner = match.winner ?? 0
        return VStack(spacing: 6) {
            Text("Fim de jogo")
                .font(.system(size: 14, weight: .semibold))
            Text("\(names[winner]) venceu")
                .font(.system(size: 12))
                .foregroundStyle(winner == 0 ? .blue : .red)
            Text("\(match.score(0)) – \(match.score(1))")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            HStack(spacing: 6) {
                Button("Desfazer") { match.undo() }
                Button("Nova") { match.reset() }
            }
            .font(.system(size: 12))
            .buttonStyle(.bordered)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
        .padding(.horizontal, 4)
    }
}

private func squareBackground(_ team: Int) -> some ShapeStyle {
    (team == 0 ? Color.blue : Color.red).opacity(0.85)
}

// MARK: - A — Toque longo abre o seletor

struct ProtoStakeA: View {
    @State private var match = ProtoStakeMatch()
    @State private var pickerTeam: Int?

    var body: some View {
        ProtoStakeChrome(match: match, hint: "Toque = 1 · segure = valor") { team in
            // Not a Button: a Button consumes the press, so the long press
            // attached to it never fires. Tap and long press have to sit on the
            // same plain view for SwiftUI to arbitrate between them — which is
            // the whole gesture under test, so getting this wrong would have
            // answered question 2 with a bug.
            Text(names[team])
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 10).fill(squareBackground(team)))
                .foregroundStyle(.white)
                .contentShape(.rect)
                .onTapGesture {
                    match.add(team, 1)
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    WKInterfaceDevice.current().play(.start)
                    pickerTeam = team
                }
        } extra: {
            EmptyView()
        }
        .sheet(isPresented: Binding(get: { pickerTeam != nil }, set: { if !$0 { pickerTeam = nil } })) {
            // A full-height grid, because the picker has to be hittable without
            // looking. Four rungs, thumb-sized.
            VStack(spacing: 6) {
                Text("Valor da mão")
                    .font(.system(size: 13, weight: .semibold))
                ForEach([[3, 6], [9, 12]], id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(row, id: \.self) { value in
                            Button("\(value)") {
                                if let team = pickerTeam { match.add(team, value) }
                                pickerTeam = nil
                            }
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(RoundedRectangle(cornerRadius: 10).fill(.gray.opacity(0.3)))
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - B — Coroa digital escolhe o valor

struct ProtoStakeB: View {
    @State private var match = ProtoStakeMatch()
    @State private var rung: Double = 0

    private var value: Int { ladder[min(max(Int(rung.rounded()), 0), ladder.count - 1)] }

    var body: some View {
        ProtoStakeChrome(match: match, hint: "Gire a coroa para o valor, toque na dupla") { team in
            Button {
                match.add(team, value)
                rung = 0
            } label: {
                Text(names[team])
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(RoundedRectangle(cornerRadius: 10).fill(squareBackground(team)))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        } extra: {
            HStack(spacing: 4) {
                ForEach(ladder, id: \.self) { rungValue in
                    Text("\(rungValue)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(rungValue == value ? Color.orange : Color.gray.opacity(0.25))
                        )
                        .foregroundStyle(rungValue == value ? .black : .gray)
                }
            }
            .focusable()
            .digitalCrownRotation(
                $rung,
                from: 0, through: Double(ladder.count - 1), by: 1,
                sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true
            )
        }
    }
}

// MARK: - C — Toque sempre credita, o chip corrige

struct ProtoStakeC: View {
    @State private var match = ProtoStakeMatch()
    @State private var showPromote = false

    var body: some View {
        ProtoStakeChrome(match: match, hint: "Toque = 1 · toque no chip para corrigir") { team in
            Button {
                match.add(team, 1)
            } label: {
                Text(names[team])
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(RoundedRectangle(cornerRadius: 10).fill(squareBackground(team)))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        } extra: {
            if let last = match.entries.last {
                Button {
                    showPromote = true
                } label: {
                    HStack(spacing: 4) {
                        Text("última: \(names[last.team]) · \(last.value)")
                        Image(systemName: "pencil")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.gray.opacity(0.28)))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(height: 22)
            }
        }
        .sheet(isPresented: $showPromote) {
            VStack(spacing: 6) {
                Text("Essa mão valia")
                    .font(.system(size: 13, weight: .semibold))
                ForEach([[1, 3, 6], [9, 12]], id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(row, id: \.self) { value in
                            Button("\(value)") {
                                if !match.entries.isEmpty {
                                    match.entries[match.entries.count - 1].value = value
                                }
                                showPromote = false
                            }
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: 10).fill(.gray.opacity(0.3)))
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Switcher

/// No floating bar on a 40mm screen — it would cover the thing being judged.
/// The variants are a list you enter and leave with the back swipe.
struct ProtoStakeGallery: View {
    var body: some View {
        List {
            NavigationLink("A — toque longo") { ProtoStakeA() }
            NavigationLink("B — coroa digital") { ProtoStakeB() }
            NavigationLink("C — chip corrige") { ProtoStakeC() }
        }
        .navigationTitle("#126")
    }
}

#endif
