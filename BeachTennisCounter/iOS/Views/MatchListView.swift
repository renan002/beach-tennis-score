import SwiftUI
import SwiftData

struct MatchListView: View {
    @EnvironmentObject private var phoneSession: PhoneSessionManager
    @Query(sort: \StoredMatch.date, order: .reverse) private var allMatches: [StoredMatch]
    @State private var showSettings = false
    @State private var filter: String = "all"

    private var matches: [StoredMatch] {
        switch filter {
        case "beachTennis": return allMatches.filter { $0.matchTypeRaw == "beachTennis" }
        case "tennis":      return allMatches.filter { $0.matchTypeRaw == "tennis" }
        default:            return allMatches
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if phoneSession.isWatchAppInstalled == false {
                    watchNotInstalledBanner
                }
                Group {
                    if matches.isEmpty {
                        emptyState
                    } else {
                        matchList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Score Counter")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    filterPicker
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(phoneSession)
            }
        }
    }

    private var filterPicker: some View {
        Menu {
            Button { filter = "all" } label: {
                Label("All", systemImage: filter == "all" ? "checkmark" : "")
            }
            Divider()
            Button { filter = "beachTennis" } label: {
                Label("Beach Tennis", systemImage: filter == "beachTennis" ? "checkmark" : "")
            }
            Button { filter = "tennis" } label: {
                Label("Tennis", systemImage: filter == "tennis" ? "checkmark" : "")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(filterLabel)
                    .font(.subheadline)
            }
        }
    }

    private var filterLabel: String {
        switch filter {
        case "beachTennis": return "Beach Tennis"
        case "tennis":      return "Tennis"
        default:            return "All"
        }
    }

    private var watchNotInstalledBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "applewatch.slash")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange))

            Text("Watch app not installed")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tennis.racket")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No matches yet")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Open the app on your Apple Watch to start a match")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var matchList: some View {
        List(matches) { match in
            NavigationLink(destination: MatchDetailView(match: match)) {
                MatchRowView(match: match)
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct MatchRowView: View {
    let match: StoredMatch

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    sportBadge
                    Text(match.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("A \(match.scoreDisplay) B")
                    .font(.headline)
            }

            Spacer()

            winnerBadge
        }
        .padding(.vertical, 4)
    }

    private var sportBadge: some View {
        Text(match.matchType == .tennis ? "Tennis" : "Beach")
            .font(.caption2.bold())
            .foregroundColor(match.matchType == .tennis ? .green : .orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(
                    (match.matchType == .tennis ? Color.green : Color.orange).opacity(0.15)
                )
            )
    }

    private var winnerBadge: some View {
        Text("Team \(match.winner.uppercased()) wins")
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.orange))
    }
}
