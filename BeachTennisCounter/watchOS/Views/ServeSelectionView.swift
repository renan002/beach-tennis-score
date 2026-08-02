import SwiftUI

struct ServeSelectionView: View {
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @Binding var isActive: Bool
    let matchType: MatchType
    @State private var navigateToScore = false
    @State private var selectedServer: Team = .a

    var body: some View {
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
            ScoreView(initialServer: selectedServer,
                      matchType: matchType,
                      teamAName: sessionManager.teamAName,
                      teamBName: sessionManager.teamBName,
                      isActive: $isActive)
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
