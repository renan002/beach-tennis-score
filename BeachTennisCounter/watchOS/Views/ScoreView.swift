import SwiftUI
import WatchKit

struct ScoreView: View {
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @EnvironmentObject private var workoutManager: WorkoutManager
    @Environment(\.dismiss) private var dismiss

    let matchType: MatchType
    @Binding var isActive: Bool

    /// The Match being scored. It owns the state, the Undo Stack and the order
    /// the effects below run in; this screen only carries them out.
    @State private var match: MatchInProgress

    // Presentation only — none of this is Match state.
    @State private var showMatchOver = false
    @State private var showHistory = false
    @State private var showCancelAlert = false

    private var state: MatchState { match.state }

    /// The headline over the live Placar, through the same shared `HeadlineScore`
/// projection the Match List and the Cartão use. Ping pong draws only on
/// `PingPongState` — games won once a best-of-N match has a complete game,
/// points otherwise (a best-of-1's terminal points stay in `PingPongState`).
    private var headlineScore: String {
        let headline = HeadlineScore.live(state)
        return "\(headline.a) – \(headline.b)"
    }

    /// Starts a fresh match, stamping the synced Team Names and the active
    /// Ruleset at match start. The ruleset is the watch's resolved value (it
    /// scores, it does not configure); for ping pong this is the whole stamped
    /// rules — target, best-of, serve mode, name.
    init(
        initialServer: Team,
        matchType: MatchType,
        teamAName: String = "",
        teamBName: String = "",
        isActive: Binding<Bool>,
        ruleset: Ruleset? = nil
    ) {
        self.matchType = matchType
        self._isActive = isActive
        _match = State(initialValue: MatchInProgress(state: MatchState.newMatch(
            matchType: matchType,
            initialServer: initialServer,
            teamAName: teamAName,
            teamBName: teamBName,
            ruleset: ruleset
        )))
    }

    /// Resumes a persisted match. The restored state carries its own stamped
    /// names and serve wiring, so no fresh-match params apply here — and it
    /// brings no Undo Stack, so the point played before the app died stays.
    init(restoredState: MatchState, isActive: Binding<Bool>) {
        self.matchType = restoredState.matchType
        self._isActive = isActive
        _match = State(initialValue: MatchInProgress(state: restoredState))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showMatchOver {
                matchOverOverlay
            } else {
                scoreContent
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            perform(match.start())
        }
        .sheet(isPresented: $showHistory) {
            MatchHistoryView(history: state.gameHistory, matchType: matchType)
                .environmentObject(sessionManager)
        }
        .alert("Cancel Match?", isPresented: $showCancelAlert) {
            Button("End Match", role: .destructive) {
                perform(match.cancel())
                isActive = false
            }
            Button("Keep Playing", role: .cancel) {}
        }
    }

    // MARK: - Score content

    private var scoreContent: some View {
        VStack(spacing: 4) {
            topBar

            if matchType == .tennis || matchType == .pingPong {
                setsWonRow
            }

            if matchType != .pingPong {
                scoreRow
            }

            squaresRow

            bottomBar
                .padding(.top, 4)
        }
    }

    private var topBar: some View {
        ZStack {
            Text("Sets")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            HStack {
                Button(action: undoLast) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(match.canUndo ? .white : .gray)
                }
                .buttonStyle(.plain)
                .disabled(!match.canUndo)
                .padding(.leading, 6)
                Spacer()
                // Live heart rate mirrors the undo arrow. Rendered only while a
                // workout feeds a reading — absent (denied / off / no sample) it
                // takes no space and the top bar looks exactly as it did before.
                if let bpm = workoutManager.currentHeartRate {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("\(Int(bpm.rounded()))")
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.trailing, 6)
                }
            }
        }
    }

    // Sets won at the top in large numerals — tennis's sets, and ping pong's
    // games displayed as "Sets" (Brazilian table-tennis convention).
    private var setsWonRow: some View {
        HStack(spacing: 0) {
            Spacer()
            Text("\(setsWonDisplay(for: .a))")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            Text("\(setsWonDisplay(for: .b))")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            Spacer()
        }
    }

    private func setsWonDisplay(for team: Team) -> Int {
        matchType == .pingPong ? state.pingGamesWon(for: team) : state.setsWon(for: team)
    }

    // The live set score; tennis games are subdued since sets won is the main focus.
    private var scoreRow: some View {
        HStack(spacing: 0) {
            Spacer()
            Text(scoreRowText(for: .a))
                .font(.system(
                    size: matchType == .tennis ? 15 : 22,
                    weight: matchType == .tennis ? .regular : .semibold
                ))
                .foregroundStyle(matchType == .tennis ? Color.secondary : .white)
                .frame(maxWidth: .infinity)
            Text(scoreRowText(for: .b))
                .font(.system(
                    size: matchType == .tennis ? 15 : 22,
                    weight: matchType == .tennis ? .regular : .semibold
                ))
                .foregroundStyle(matchType == .tennis ? Color.secondary : .white)
                .frame(maxWidth: .infinity)
            Spacer()
        }
    }

    private func scoreRowText(for team: Team) -> String {
        "\(state.setScore(for: team))"
    }

    private var squaresRow: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
                .opacity(state.servingTeam == .a ? 1 : 0)
                .padding(.leading, 2)

            scoreSquare(team: .a, color: sessionManager.teamAColor)
                .padding(.leading, 4)

            scoreSquare(team: .b, color: sessionManager.teamBColor)
                .padding(.trailing, 4)

            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
                .opacity(state.servingTeam == .b ? 1 : 0)
                .padding(.trailing, 2)
        }
        .padding(.horizontal, 2)
    }

    private var bottomBar: some View {
        ZStack {
            Button {
                showCancelAlert = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.gray)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(state.gameHistory.isEmpty ? .gray : .white)
                }
                .buttonStyle(.plain)
                .disabled(state.gameHistory.isEmpty)
                .padding(.trailing, 6)
            }
        }
    }

    @ViewBuilder
    private func scoreSquare(team: Team, color: Color) -> some View {
        let label = scoreLabel(for: team)

        Button {
            awardPoint(to: team)
        } label: {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(maxWidth: .infinity)
                .aspectRatio(1.0, contentMode: .fit)
                .overlay(
                    Text(label)
                        .font(.system(size: label.count > 2 ? 24 : 34, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.4)
                )
                .glassEffect(in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func scoreLabel(for team: Team) -> String {
        switch matchType {
        case .pingPong:
            return "\(state.pingPoints(for: team))"
        case .tennis, .beachTennis:
            if state.isTiebreak {
                return "\(state.tiebreakScore(for: team))"
            }
            if matchType == .tennis, let advTeam = state.advantageTeam {
                return advTeam == team ? "Ad" : "40"
            }
            return state.point(for: team).display
        }
    }

    // MARK: - Match over overlay

    private var matchOverOverlay: some View {
        VStack(spacing: 10) {
            Text("Match Over!")
                .font(.headline)
                .foregroundStyle(.white)

            Text("\(state.winner.map { state.teamName(for: $0) } ?? "") wins")
                .font(.subheadline)
                .foregroundStyle(.orange)

            if matchType == .tennis {
                Text("\(state.setsWonA) – \(state.setsWonB)")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            } else if matchType == .pingPong {
                Text(headlineScore)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            } else {
                Text("\(state.setScoreA) – \(state.setScoreB)")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }

            // One static line pointing to Estatísticas on the iPhone — shown to
            // everyone, no entitlement awareness. The watch never links StoreKit
            // and shows no purchase UI; this is its only Pro-adjacent touchpoint.
            Text("See your stats on iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Done") {
                isActive = false
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .glassEffect(in: .capsule)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    // MARK: - Actions

    private func awardPoint(to team: Team) {
        let effects = match.awardPoint(to: team)
        // Raised before the effects run, as it was when this was an observer on
        // the match-over flag: the overlay never waits on the stats snapshot.
        if state.isMatchOver {
            showMatchOver = true
        }
        perform(effects)
    }

    private func undoLast() {
        perform(match.undo())
    }

    // MARK: - Effects

    /// Carries out what an interaction returned, in the order it returned it.
    /// This screen decides nothing here — the ordering that matters (the stats
    /// snapshot riding on the send, before the workout is torn down) is the
    /// module's, and is tested there.
    ///
    /// Synchronous and in order, deliberately: `.persist` saves whatever the
    /// module holds *now*, so an effect made async here would silently save a
    /// later state than the one it was emitted for.
    private func perform(_ effects: [MatchInProgress.Effect]) {
        for effect in effects {
            switch effect {
            case .persist:
                MatchPersistence.save(match.state)

            case .clearPersisted:
                MatchPersistence.clear()

            case .haptic:
                WKInterfaceDevice.current().play(.click)

            case .startWorkout:
                // The monitoring flag is watch-session state, not Match state,
                // so the screen supplies it here. The sport's physicality comes
                // from the match type (every sport shipped today is physical),
                // and the type travels along so the workout is started under the
                // right activity.
                workoutManager.matchDidStart(
                    monitoringEnabled: sessionManager.healthMonitoringEnabled,
                    sportIsPhysical: matchType.isPhysicalSport,
                    matchTypeRaw: matchType.rawValue
                )

            case .sendResult(let finished, let duration):
                // Snapshot synchronously so the send never waits on HealthKit —
                // and so it happens while the builder still has stats to give.
                let stats = workoutManager.snapshotStats()
                sessionManager.sendMatchResult(
                    finished,
                    duration: duration,
                    activeCalories: stats.activeCalories,
                    avgHeartRate: stats.avgHeartRate
                )

            case .endWorkout:
                workoutManager.endAndFinish()

            case .cancelWorkout(let elapsed):
                // Below ~2 min the workout is discarded (accidental start), above
                // it is saved (real exercise); the manager applies the policy.
                workoutManager.cancelWorkout(elapsed: elapsed)
            }
        }
    }
}
