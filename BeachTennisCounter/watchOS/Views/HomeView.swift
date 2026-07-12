import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @State private var navigateToSetup = false
    @State private var navigateToTypeSelection = false
    @State private var selectedMatchType: MatchType = .beachTennis

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
                }
            }
            .navigationBarHidden(true)
            // Multiple mode: goes through type selection, which handles the rest
            .navigationDestination(isPresented: $navigateToTypeSelection) {
                MatchTypeSelectionView(isActive: $navigateToTypeSelection)
            }
            // Single-sport mode: goes directly to serve selection
            .navigationDestination(isPresented: $navigateToSetup) {
                ServeSelectionView(isActive: $navigateToSetup, matchType: selectedMatchType)
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
