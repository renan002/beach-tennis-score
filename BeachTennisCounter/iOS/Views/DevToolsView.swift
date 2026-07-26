import SwiftUI
import SwiftData

// `DEV_FLAVOR`, not `DEBUG`: this is the affordance, and it must not exist in
// the production bundle id's build at all — not even the debuggable one. `DEBUG`
// is defined for both `Debug` and `Dev` (XcodeGen sets it for every debug-type
// config), so only `DEV_FLAVOR` means "the flavor that installs alongside the
// App Store app". The same condition gates the Settings `DEV` marker; see
// project.yml.
//
// Copy here is deliberately not in the String Catalog. Dev Tools ships to one
// device — mine — and a missing catalog entry renders its key, so these read as
// English while the rest of the app stays pt-BR.
#if DEV_FLAVOR

/// The tools on the Dev Tools screen. One today; the tab bar is here because the
/// second one is a new case and nothing else. Past four, iOS folds the rest into
/// its own "More" list.
enum DevTool: String, CaseIterable, Identifiable, Hashable {
    case seeder = "Seeder"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .seeder: return "wand.and.stars"
        }
    }
}

struct DevToolsView: View {
    @State private var tool: DevTool = .seeder

    var body: some View {
        TabView(selection: $tool) {
            Tab(DevTool.seeder.rawValue, systemImage: DevTool.seeder.icon, value: DevTool.seeder) {
                SeederToolView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Fills — and empties — the Dev store's Match History.
///
/// Wipe cannot reach the production store, and not because of a check made here:
/// `LiveStore.directory` resolves through the App Group named by this build's
/// `AppGroupIdentifier`, and a Dev build holds no entitlement for
/// `group.com.renan.beachtennis`. There is no code path from this screen to the
/// App Store app's matches.
struct SeederToolView: View {
    @EnvironmentObject private var phoneSession: PhoneSessionManager
    @Environment(\.modelContext) private var modelContext
    @Query private var storedMatches: [StoredMatch]

    @State private var params = SeedParameters()
    @State private var confirmWipe = false
    @State private var status: String?

    var body: some View {
        Form {
            Section("Population") {
                Picker("Sport", selection: $params.sport) {
                    Text("Beach Tennis").tag(SeedParameters.Sport.beachTennis)
                    Text("Tennis").tag(SeedParameters.Sport.tennis)
                    Text("Mixed").tag(SeedParameters.Sport.mixed)
                }
                Stepper("Matches: \(params.count)", value: $params.count, in: 1...200)
                DatePicker("From", selection: $params.from, displayedComponents: .date)
                DatePicker("To", selection: $params.to, displayedComponents: .date)
            }

            Section {
                VStack(alignment: .leading) {
                    Text("Team A strength: \(Int(params.teamAStrength * 100))%")
                        .font(.subheadline)
                    Slider(value: $params.teamAStrength, in: 0.35...0.65)
                }
                Stepper("Seed: \(params.seed)", value: $params.seed, in: 0...9999)
            } header: {
                Text("Shape")
            } footer: {
                Text("Point-win probability for Team A. The same seed and parameters produce the same matches.")
            }

            Section {
                Button("Seed \(params.count) matches", action: seed)
                Button("Wipe Match History", role: .destructive) { confirmWipe = true }
                    .disabled(storedMatches.isEmpty)
            } footer: {
                Text(footer)
            }
            .confirmationDialog(
                "Wipe all \(storedMatches.count) matches?",
                isPresented: $confirmWipe,
                titleVisibility: .visible
            ) {
                Button("Wipe", role: .destructive, action: wipe)
                Button("Cancel", role: .cancel) {}
            }
        }
        .navigationTitle("Seeder")
    }

    private var footer: String {
        if let status { return status }
        return "\(storedMatches.count) matches in the Dev store. Seeded matches are played out by ScoreEngine, so their Game Logs are real."
    }

    private func seed() {
        let matches = MatchSeeder.makeMatches(
            params,
            teamAName: phoneSession.teamAName,
            teamBName: phoneSession.teamBName
        )
        for match in matches {
            modelContext.insert(StoredMatch(seeded: match))
        }
        try? modelContext.save()
        status = "Seeded \(matches.count) matches."
    }

    private func wipe() {
        for match in storedMatches {
            modelContext.delete(match)
        }
        try? modelContext.save()
        status = "Wiped."
    }
}

/// The row that mounts Dev Tools at the bottom of Settings. Two taps deep and
/// invisible unless looked for — which is the point: a tool that can wipe a
/// store should not sit beside Estatísticas at equal weight.
struct DevToolsSettingsSection: View {
    var body: some View {
        Section("Developer") {
            NavigationLink {
                DevToolsView()
            } label: {
                Label("Dev Tools", systemImage: "hammer")
            }
        }
    }
}

#endif
