import SwiftUI
import WatchKit

struct ScoreView: View {
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @Environment(\.dismiss) private var dismiss

    let initialServer: Team
    @Binding var isActive: Bool

    @State private var state: MatchState
    @State private var history: [MatchState] = []
    @State private var showMatchOver = false
    @State private var showHistory = false
    @State private var showCancelAlert = false
    @State private var matchStartTime = Date()

    init(initialServer: Team, isActive: Binding<Bool>) {
        self.initialServer = initialServer
        self._isActive = isActive
        var s = MatchState()
        s.servingTeam = initialServer
        s.initialServer = initialServer
        s.tiebreakFirstServer = initialServer
        s.matchStartDate = Date()
        _state = State(initialValue: s)
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
        .onChange(of: state.isMatchOver) { _, isOver in
            guard isOver else { return }
            showMatchOver = true
            sessionManager.sendMatchResult(state, duration: Date().timeIntervalSince(state.matchStartDate))
        }
        .sheet(isPresented: $showHistory) {
            MatchHistoryView(history: state.gameHistory)
        }
        .alert("Cancel Match?", isPresented: $showCancelAlert) {
            Button("End Match", role: .destructive) { isActive = false }
            Button("Keep Playing", role: .cancel) {}
        }
    }

    // MARK: - Score content

    private var scoreContent: some View {
        VStack(spacing: 4) {
            // Top bar: undo (back) on left, "Sets" centered
            ZStack {
                Text("Sets")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)

                HStack {
                    Button(action: undoLast) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(history.isEmpty ? .gray : .white)
                    }
                    .buttonStyle(.plain)
                    .disabled(history.isEmpty)
                    .padding(.leading, 6)
                    Spacer()
                }
            }

            HStack(spacing: 0) {
                Spacer()
                Text("\(state.setScoreA)")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                Text("\(state.setScoreB)")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                Spacer()
            }

            // Score squares row
            HStack(spacing: 0) {
                // Serving dot (left side)
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .opacity(state.servingTeam == .a ? 1 : 0)
                    .padding(.leading, 2)

                scoreSquare(team: .a, color: sessionManager.teamAColor)
                    .padding(.leading, 4)

                scoreSquare(team: .b, color: sessionManager.teamBColor)
                    .padding(.trailing, 4)

                // Serving dot (right side)
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .opacity(state.servingTeam == .b ? 1 : 0)
                    .padding(.trailing, 2)
            }
            .padding(.horizontal, 2)

            // Bottom bar: cancel centered, history on right
            ZStack {
                Button {
                    showCancelAlert = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
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
                            .foregroundColor(state.gameHistory.isEmpty ? .gray : .white)
                    }
                    .buttonStyle(.plain)
                    .disabled(state.gameHistory.isEmpty)
                    .padding(.trailing, 6)
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func scoreSquare(team: Team, color: Color) -> some View {
        let label = scoreLabel(for: team)

        Button {
            awardPoint(to: team)
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(maxWidth: .infinity)
                .aspectRatio(1.0, contentMode: .fit)
                .overlay(
                    Text(label)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func scoreLabel(for team: Team) -> String {
        if state.isTiebreak {
            return "\(state.tiebreakScore(for: team))"
        }
        return state.point(for: team).display
    }

    // MARK: - Match over overlay

    private var matchOverOverlay: some View {
        VStack(spacing: 12) {
            Text("Match Over!")
                .font(.headline)
                .foregroundColor(.white)

            Text("\(state.winner?.displayName ?? "") wins")
                .font(.subheadline)
                .foregroundColor(.orange)

            Text("\(state.setScoreA) – \(state.setScoreB)")
                .font(.title3.bold())
                .foregroundColor(.white)

            Button("Done") {
                isActive = false
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
    }

    // MARK: - Actions

    private func awardPoint(to team: Team) {
        history.append(state)
        ScoreEngine.awardPoint(to: team, state: &state)
        WKInterfaceDevice.current().play(.click)
    }

    private func undoLast() {
        guard let previous = history.popLast() else { return }
        state = previous
        WKInterfaceDevice.current().play(.click)
    }
}
