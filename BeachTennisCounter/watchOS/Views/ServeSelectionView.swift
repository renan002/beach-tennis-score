import SwiftUI

struct ServeSelectionView: View {
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @Binding var isActive: Bool
    let matchType: MatchType
    @State private var navigateToScore = false
    @State private var selectedServer: Team = .a

    var body: some View {
        // A sport with no serve (truco) has nothing to ask: go straight to the
        // Placar. `.a` is a placeholder the engine never reads for it.
        if matchType.hasServe {
            servePicker
        } else {
            scoreView(initialServer: .a)
        }
    }

    private func scoreView(initialServer: Team) -> ScoreView {
        ScoreView(initialServer: initialServer,
                  matchType: matchType,
                  teamAName: sessionManager.teamAName,
                  teamBName: sessionManager.teamBName,
                  isActive: $isActive,
                  ruleset: sessionManager.ruleset(for: matchType))
    }

    private var servePicker: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 6) {
                Text("Who serves first?")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                Button {
                    selectedServer = .a
                    navigateToScore = true
                } label: {
                    teamButton(color: sessionManager.teamAColor,
                               label: TeamName.resolved(sessionManager.teamAName, for: .a))
                }
                .buttonStyle(.plain)

                Button {
                    selectedServer = .b
                    navigateToScore = true
                } label: {
                    teamButton(color: sessionManager.teamBColor,
                               label: TeamName.resolved(sessionManager.teamBName, for: .b))
                }
                .buttonStyle(.plain)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToScore) {
            scoreView(initialServer: selectedServer)
        }
    }

    @ViewBuilder
    private func teamButton(color: Color, label: String) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .overlay(
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}
