import SwiftUI
import UIKit

/// The truco Placar on the phone (#126 variant D): two columns, a two-column
/// notebook of Mãos, and a standing "Valor da mão" bar. No serve, no workout,
/// no hidden gesture — pick the Valor, then tap the dupla.
///
/// Like the watch's ScoreView it holds a `MatchInProgress` and decides nothing:
/// the module owns the rules, the end of the match and the effect order, and
/// this screen only carries the effects out. A finished match is filed through
/// `PhoneSessionManager.record`, the same insert the watch's results use.
struct TrucoPlacarView: View {
    @EnvironmentObject private var phoneSession: PhoneSessionManager
    @State private var match: MatchInProgress?
    /// The Valor the next tap credits. Snaps back to the base after every Mão so
    /// the common case never stays armed at 12.
    @State private var pending = 1
    @State private var confirmDiscard = false

    var body: some View {
        Group {
            if let match {
                scoreboard(match.state)
            } else {
                idle
            }
        }
        .navigationTitle(MatchType.truco.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { resumeSavedMatch() }
    }

    // MARK: - Idle

    private var idle: some View {
        VStack(spacing: 16) {
            Image(systemName: MatchType.truco.icon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(RulesetLibrary.activeRuleset(for: .truco).name)
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("New match", action: startMatch)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scoreboard

    private func scoreboard(_ state: MatchState) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                column(.a, state)
                column(.b, state)
            }
            .frame(height: 190)

            notebook(state)

            valueBar(state)
        }
        .onAppear { pending = baseValue(state) }
    }

    private func column(_ team: Team, _ state: MatchState) -> some View {
        Button {
            award(to: team)
        } label: {
            VStack(spacing: 2) {
                Text(state.teamName(for: team))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                Text("\(state.setScore(for: team))")
                    .font(.system(size: 82, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Kept inside the safe area: a solid column would otherwise run
            // up under the title and the gear.
            .background(color(team).opacity(0.85), ignoresSafeAreaEdges: [])
        }
        .buttonStyle(.plain)
        .disabled(state.isMatchOver)
    }

    /// The napkin ledger: one column per dupla under its score, oldest at the
    /// top, scroll anchored to the bottom so the newest Mão is in view. Both
    /// running totals are written on every row; only the dupla that scored is
    /// in its colour and carries the correction menu.
    private func notebook(_ state: MatchState) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(state.gameHistory.enumerated()), id: \.offset) { index, record in
                        HStack(spacing: 0) {
                            cell(index, record, .a, state)
                            Divider()
                            cell(index, record, .b, state)
                        }
                        .frame(height: 46)
                        .id(index)
                        Divider()
                    }
                }
            }
            // Not `defaultScrollAnchor(.bottom)`: that also pins a short ledger
            // to the bottom of the screen, and a notebook starts at the top.
            .onChange(of: state.gameHistory.count) { _, count in
                proxy.scrollTo(count - 1, anchor: .bottom)
            }
        }
        .overlay {
            if state.gameHistory.isEmpty {
                ContentUnavailableView(
                    "No hands yet",
                    systemImage: "list.bullet",
                    description: Text("Pick the value below, then tap a team.")
                )
            }
        }
        // The centre rule runs the whole height, so the columns still read as
        // columns where nothing is written yet.
        .overlay { Divider().frame(maxWidth: 1, maxHeight: .infinity) }
        .overlay { if state.isMatchOver { matchOverCard(state) } }
    }

    private func cell(_ index: Int, _ record: GameRecord, _ team: Team, _ state: MatchState) -> some View {
        let scored = record.winner == team
        let total = team == .a ? record.setScoreA : record.setScoreB
        let text = Text("\(total)")
            .font(.title3.weight(scored ? .bold : .regular).monospacedDigit())
            .foregroundStyle(scored ? color(team) : Color.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            // Team and running total, so a cell is not a bare number.
            .accessibilityLabel(Text("\(state.teamName(for: team)): \(total)"))
        return Group {
            if scored && !state.isMatchOver {
                Menu {
                    ForEach(stakes(state), id: \.self) { value in
                        Button {
                            apply { $0.correctHand(at: index, value: value) }
                        } label: {
                            if value == MatchState.trucoHandValue(record) {
                                Label("\(value)", systemImage: "checkmark")
                            } else {
                                Text("\(value)")
                            }
                        }
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        apply { $0.removeHand(at: index) }
                    }
                } label: { text }
            } else {
                text
            }
        }
    }

    private func matchOverCard(_ state: MatchState) -> some View {
        let winner = state.winner ?? .a
        return VStack(spacing: 10) {
            Text("Game over").font(.headline)
            Text("\(state.teamName(for: winner)) won")
                .font(.subheadline)
                .foregroundStyle(color(winner))
            Text("\(state.setScoreA) – \(state.setScoreB)")
                .font(.title3.bold().monospacedDigit())
            Button("New match", action: startMatch)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(radius: 12)
        )
        .padding()
    }

    private func valueBar(_ state: MatchState) -> some View {
        VStack(spacing: 12) {
            Text("Hand value")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(stakes(state), id: \.self) { value in
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
                    .accessibilityAddTraits(pending == value ? .isSelected : [])
                }
            }
            .disabled(state.isMatchOver)

            HStack {
                Button("Undo") { perform(match?.undo() ?? []) }
                    .disabled(!(match?.canUndo ?? false))
                Spacer()
                Text("Playing to \(state.ruleset.truco?.pointsTarget ?? 0)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Discard match", role: .destructive) { confirmDiscard = true }
                    .disabled(state.isMatchOver)
            }
            .font(.footnote)
        }
        .padding([.horizontal, .top])
        .padding(.bottom, 8)
        .background(.thinMaterial)
        .confirmationDialog("Discard this match?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard match", role: .destructive) { discard() }
            Button("Keep playing", role: .cancel) {}
        }
    }

    // MARK: - Actions

    private func stakes(_ state: MatchState) -> [Int] { state.ruleset.truco?.stakes ?? [1] }
    private func baseValue(_ state: MatchState) -> Int { stakes(state).first ?? 1 }

    private func color(_ team: Team) -> Color {
        Color(hex: team == .a ? phoneSession.teamAColorHex : phoneSession.teamBColorHex)
    }

    private func startMatch() {
        let state = MatchState.newMatch(
            matchType: .truco,
            initialServer: .a,
            teamAName: phoneSession.teamAName,
            teamBName: phoneSession.teamBName,
            ruleset: RulesetLibrary.activeRuleset(for: .truco)
        )
        let started = MatchInProgress(state: state)
        pending = baseValue(state)
        match = started
        perform(started.start(), state: state)
    }

    /// Resumes a match the app was killed in. `MatchPersistence` is the same
    /// store the watch uses, on the phone's own defaults.
    private func resumeSavedMatch() {
        guard match == nil, let saved = MatchPersistence.load(), saved.matchType == .truco else { return }
        pending = baseValue(saved)
        match = MatchInProgress(state: saved)
    }

    private func award(to team: Team) {
        let value = pending
        apply { $0.awardPoint(to: team, value: value) }
        pending = match.map { baseValue($0.state) } ?? 1
    }

    private func discard() {
        guard let m = match else { return }
        perform(m.cancel(), state: m.state)
        match = nil
    }

    /// Runs one interaction on the module and carries out what it returned.
    private func apply(_ change: (inout MatchInProgress) -> [MatchInProgress.Effect]) {
        guard var m = match else { return }
        let effects = change(&m)
        match = m
        perform(effects, state: m.state)
    }

    private func perform(_ effects: [MatchInProgress.Effect]) {
        guard let m = match else { return }
        perform(effects, state: m.state)
    }

    /// Synchronous and in order, like the watch: `.persist` saves the state the
    /// effect was emitted for.
    private func perform(_ effects: [MatchInProgress.Effect], state: MatchState) {
        for effect in effects {
            switch effect {
            case .persist:
                MatchPersistence.save(state)
            case .clearPersisted:
                MatchPersistence.clear()
            case .haptic:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .sendResult(let finished, let duration):
                if let payload = MatchResultPayload(finished: finished, duration: duration) {
                    phoneSession.record(payload)
                }
            case .startWorkout, .endWorkout, .cancelWorkout:
                break // truco is not a physical sport (MatchType.isPhysicalSport)
            }
        }
    }
}
