import SwiftUI
import WatchKit

struct ScoreView: View {
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @EnvironmentObject private var workoutManager: WorkoutManager
    @Environment(\.dismiss) private var dismiss

    let initialServer: Team
    let matchType: MatchType
    @Binding var isActive: Bool

    @State private var state: MatchState
    @State private var history: [MatchState] = []
    @State private var showMatchOver = false
    @State private var showHistory = false
    @State private var showCancelAlert = false

    init(
        initialServer: Team,
        matchType: MatchType,
        teamAName: String = "",
        teamBName: String = "",
        restoredState: MatchState? = nil,
        isActive: Binding<Bool>
    ) {
        self.initialServer = initialServer
        self.matchType = restoredState?.matchType ?? matchType
        self._isActive = isActive
        if let restored = restoredState {
            _state = State(initialValue: restored)
        } else {
            _state = State(initialValue: MatchState.newMatch(
                matchType: matchType,
                initialServer: initialServer,
                teamAName: teamAName,
                teamBName: teamBName
            ))
        }
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
            MatchPersistence.save(state)
            workoutManager.matchDidStart(monitoringEnabled: sessionManager.healthMonitoringEnabled)
        }
        .onChange(of: state.isMatchOver) { _, isOver in
            guard isOver else { return }
            showMatchOver = true
            // Snapshot stats synchronously first so the result send never waits on
            // HealthKit, then end/finish the workout asynchronously.
            let stats = workoutManager.snapshotStats()
            sessionManager.sendMatchResult(
                state,
                duration: Date().timeIntervalSince(state.matchStartDate),
                activeCalories: stats.activeCalories,
                avgHeartRate: stats.avgHeartRate
            )
            workoutManager.endAndFinish()
        }
        .sheet(isPresented: $showHistory) {
            MatchHistoryView(history: state.gameHistory, matchType: matchType)
                .environmentObject(sessionManager)
        }
        .alert("Cancel Match?", isPresented: $showCancelAlert) {
            Button("End Match", role: .destructive) {
                // Below ~2 min the workout is discarded (accidental start), above it
                // is saved (real exercise); the manager applies the policy.
                workoutManager.cancelWorkout(elapsed: Date().timeIntervalSince(state.matchStartDate))
                MatchPersistence.clear()
                isActive = false
            }
            Button("Keep Playing", role: .cancel) {}
        }
    }

    // MARK: - Score content

    private var scoreContent: some View {
        VStack(spacing: 4) {
            topBar

            if matchType == .tennis {
                tennisSetRow
            }

            scoreRow

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
                        .foregroundStyle(history.isEmpty ? .gray : .white)
                }
                .buttonStyle(.plain)
                .disabled(history.isEmpty)
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

    // Tennis: sets won at the top in large numerals
    private var tennisSetRow: some View {
        HStack(spacing: 0) {
            Spacer()
            Text("\(state.setsWonA)")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            Text("\(state.setsWonB)")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            Spacer()
        }
    }

    // Current set games (subdued for tennis since sets won is the main focus)
    private var scoreRow: some View {
        HStack(spacing: 0) {
            Spacer()
            Text("\(state.setScoreA)")
                .font(.system(
                    size: matchType == .tennis ? 15 : 22,
                    weight: matchType == .tennis ? .regular : .semibold
                ))
                .foregroundStyle(matchType == .tennis ? Color.secondary : .white)
                .frame(maxWidth: .infinity)
            Text("\(state.setScoreB)")
                .font(.system(
                    size: matchType == .tennis ? 15 : 22,
                    weight: matchType == .tennis ? .regular : .semibold
                ))
                .foregroundStyle(matchType == .tennis ? Color.secondary : .white)
                .frame(maxWidth: .infinity)
            Spacer()
        }
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
        if state.isTiebreak {
            return "\(state.tiebreakScore(for: team))"
        }
        if matchType == .tennis, let advTeam = state.advantageTeam {
            return advTeam == team ? "Ad" : "40"
        }
        return state.point(for: team).display
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
            } else {
                Text("\(state.setScoreA) – \(state.setScoreB)")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }

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
        history.append(state)
        ScoreEngine.awardPoint(to: team, state: &state)
        MatchPersistence.save(state)
        WKInterfaceDevice.current().play(.click)
    }

    private func undoLast() {
        guard let previous = history.popLast() else { return }
        state = previous
        MatchPersistence.save(state)
        WKInterfaceDevice.current().play(.click)
    }
}
