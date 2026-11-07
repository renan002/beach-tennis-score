import SwiftUI

/// The sport's Rules entry point inside Settings: a Rules row that opens a
/// sport list — beach tennis, ping pong and truco are editable, tennis is a
/// frozen preset shown read-only.
struct RulesSettingsView: View {
    /// Bumped on every library save: the row summaries read the library, which
    /// SwiftUI cannot observe, so an edit made one screen deeper re-renders them.
    @State private var libraryVersion = 0

    var body: some View {
        let _ = libraryVersion
        List {
            NavigationLink {
                BeachTennisRulesView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Beach Tennis")
                        Text(activeBeachSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: MatchType.beachTennis.icon)
                }
            }

            NavigationLink {
                PingPongRulesView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ping pong")
                        Text(activePingSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: MatchType.pingPong.icon)
                }
            }

            NavigationLink {
                TrucoRulesView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Truco")
                        Text(activeTrucoSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: MatchType.truco.icon)
                }
            }

            Section("Fixed rules") {
                FrozenSportRow(sport: .tennis)
            }
        }
        .navigationTitle("Rules")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: RulesetLibrary.didChangeNotification)) { _ in
            libraryVersion += 1
        }
    }

    private var activeBeachSummary: String {
        let beach = RulesetLibrary.activeRuleset(for: .beachTennis).beachRules
        return beach.isPreset ? beach.name : BeachTennisRulesView.summary(beach)
    }

    private var activeTrucoSummary: String {
        let truco = RulesetLibrary.activeRuleset(for: .truco).truco ?? .paulista
        return truco.isPreset ? truco.name : TrucoRulesView.summary(truco)
    }

    private var activePingSummary: String {
        guard let ping = RulesetLibrary.activeRuleset(for: .pingPong).pingPong else {
            return PingPongRuleset.oficial.name
        }
        if PingPongRuleset.presets.contains(where: { $0.identifier == ping.identifier }) {
            return ping.name
        }
        return String(localized: "\(ping.pointsTarget) points per set · best of \(ping.bestOf) · \(ping.serveMode.displayName)")
    }
}

/// Tennis has no Rules editor: the active value is always the
/// sport's built-in preset, shown read-only with a summary of what it is.
private struct FrozenSportRow: View {
    let sport: MatchType

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(sport.displayName)
                Text("Default · \(RulesetLibrary.activeRuleset(for: sport).name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: sport.icon)
        }
    }
}