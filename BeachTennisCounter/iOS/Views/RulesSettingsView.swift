import SwiftUI

/// The sport's Rules entry point inside Settings: a Rules row that opens a
/// sport list — ping pong is editable, beach tennis and tennis are frozen
/// presets shown read-only.
struct RulesSettingsView: View {
    var body: some View {
        List {
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
                    Image(systemName: "tabletennis")
                }
            }

            Section("Fixed rules") {
                FrozenSportRow(sport: .beachTennis)
                FrozenSportRow(sport: .tennis)
            }
        }
        .navigationTitle("Rules")
        .navigationBarTitleDisplayMode(.inline)
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

/// Beach tennis and tennis have no Rules editor: the active value is always the
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