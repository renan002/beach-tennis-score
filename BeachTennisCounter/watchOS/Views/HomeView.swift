import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @State private var navigateToSetup = false
    @State private var navigateToTypeSelection = false
    @State private var selectedMatchType: MatchType = .beachTennis
    @State private var resumableMatch: MatchState? = nil
    @State private var navigateToResume = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 12) {
                    Button {
                        handleNewMatch()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle().stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                            Image(systemName: "plus")
                                .font(.system(size: 36, weight: .light))
                                .foregroundStyle(.white)
                        }
                        .glassEffect(in: .circle)
                    }
                    .buttonStyle(.plain)

                    Text("New Match")
                        .font(.headline)
                        .foregroundStyle(.white)

                    if resumableMatch != nil {
                        Button {
                            navigateToResume = true
                        } label: {
                            Label("Resume Match", systemImage: "arrow.uturn.forward.circle")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                resumableMatch = MatchPersistence.load()
            }
            // Multiple mode: goes through type selection, which handles the rest
            .navigationDestination(isPresented: $navigateToTypeSelection) {
                MatchTypeSelectionView(isActive: $navigateToTypeSelection)
            }
            // Single-sport mode: goes directly to serve selection
            .navigationDestination(isPresented: $navigateToSetup) {
                ServeSelectionView(isActive: $navigateToSetup, matchType: selectedMatchType)
            }
            .navigationDestination(isPresented: $navigateToResume) {
                if let match = resumableMatch {
                    ScoreView(
                        initialServer: match.servingTeam,
                        matchType: match.matchType,
                        restoredState: match,
                        isActive: $navigateToResume
                    )
                }
            }
        }
    }

    private func handleNewMatch() {
        switch sessionManager.sportSetting {
        case "tennis":
            selectedMatchType = .tennis
            navigateToSetup = true
        case "multiple":
            navigateToTypeSelection = true
        default:
            selectedMatchType = .beachTennis
            navigateToSetup = true
        }
    }
}
