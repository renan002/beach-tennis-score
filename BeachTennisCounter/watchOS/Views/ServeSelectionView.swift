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
                               label: displayName(sessionManager.teamAName, fallback: "Team A"))
                }
                .buttonStyle(.plain)

                Button {
                    selectedServer = .b
                    navigateToScore = true
                } label: {
                    teamButton(color: sessionManager.teamBColor,
                               label: displayName(sessionManager.teamBName, fallback: "Team B"))
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

    /// The synced team name, or the localized slot label when the name is empty.
    /// The result is a resolved plain string so a user-entered name never goes
    /// through String Catalog lookup — only the fallback literal is localized.
    private func displayName(_ name: String, fallback: LocalizedStringResource) -> String {
        name.isEmpty ? String(localized: fallback) : name
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
