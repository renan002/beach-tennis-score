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

                    // PROTOTYPE — issue #126. Leaves with the prototype branch.
                    #if DEV_FLAVOR
                    NavigationLink {
                        ProtoStakeGallery()
                    } label: {
                        Label("Proto #126", systemImage: "scribble.variable")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .tint(.yellow)
                    #endif
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
                    ScoreView(restoredState: match, isActive: $navigateToResume)
                }
            }
        }
    }

    /// One branch, on the setting itself: a setting that names a sport starts
    /// it, and the one that doesn't — Vários — asks first.
    private func handleNewMatch() {
        if let sport = sessionManager.sportSetting.startSport {
            selectedMatchType = sport
            navigateToSetup = true
        } else {
            navigateToTypeSelection = true
        }
    }
}
