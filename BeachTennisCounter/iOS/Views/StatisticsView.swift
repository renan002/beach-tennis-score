import SwiftUI
import SwiftData

/// Estatísticas: on-device insights computed from the live Match History. A
/// thin shell around the pure `MatchStatistics` seam — the view formats and
/// lays out; every number comes from the calculator.
///
/// Ships ungated in this release; the Pro lock arrives in the gating ticket.
struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StoredMatch.date, order: .reverse) private var matches: [StoredMatch]

    var body: some View {
        // Computed once per render — every section reads from this one value
        // rather than reconstructing (and re-sorting) the stats on each access.
        let stats = MatchStatistics(matches: matches)
        return NavigationStack {
            Group {
                if stats.isEmpty {
                    emptyState
                } else {
                    statsList(stats)
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No statistics yet")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Play a match to start building your statistics")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Stats list

    private func statsList(_ stats: MatchStatistics) -> some View {
        List {
            Section {
                statRow("Matches played", "\(stats.matchesPlayed)")
                statRow("Wins", "\(stats.wins)")
                statRow("Win rate", stats.winRate.formatted(.percent.precision(.fractionLength(0))))
            } header: {
                Text("Overview")
            } footer: {
                // The v1 identity assumption, stated on screen: the player is
                // Team A (the scoring UI's default). Everything here is from
                // Team A's point of view.
                Text("Statistics are calculated for Team A.")
            }

            Section("Streaks") {
                statRow("Current winning streak", "\(stats.currentStreak)")
                statRow("Best winning streak", "\(stats.bestStreak)")
            }

            Section("Records") {
                statRow("Golden points", recordText(won: stats.goldenPointsWon, lost: stats.goldenPointsLost))
                statRow("Super tiebreaks", recordText(won: stats.superTiebreaksWon, lost: stats.superTiebreaksLost))
            }

            Section("By sport") {
                statRow(verbatim: MatchType.beachTennis.displayName, "\(stats.beachMatches)")
                statRow(verbatim: MatchType.tennis.displayName, "\(stats.tennisMatches)")
            }

            Section("Court time") {
                statRow("Total", durationText(stats.totalDuration))
                statRow("Average per match", durationText(stats.averageDuration))
            }
        }
    }

    private func statRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        row(label: Text(label), value: value)
    }

    /// The sport names arrive already localized (`MatchType.displayName`); a
    /// second String Catalog lookup would miss, so they go in verbatim.
    private func statRow(verbatim label: String, _ value: String) -> some View {
        row(label: Text(verbatim: label), value: value)
    }

    private func row(label: Text, value: String) -> some View {
        HStack {
            label
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
    }

    /// A win–loss record, "5–2". Plain formatting, not localized digits, so it
    /// reads the same in every language.
    private func recordText(won: Int, lost: Int) -> String {
        "\(won)–\(lost)"
    }

    /// Hours and minutes, localized by the system — a bare "90:00" reads as a
    /// score, not a span of time.
    private func durationText(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
