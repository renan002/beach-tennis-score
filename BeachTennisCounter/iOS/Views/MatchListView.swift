import SwiftUI
import SwiftData

struct MatchListView: View {
    @EnvironmentObject private var phoneSession: PhoneSessionManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredMatch.date, order: .reverse) private var allMatches: [StoredMatch]
    @State private var showSettings = false
    @State private var showStatistics = false
    @State private var filter: String = "all"
    @State private var quarantines: [QuarantinedStore] = []

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
                if restorableMatchesExist {
                    restoreNotice
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
                        showStatistics = true
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings, onDismiss: reloadQuarantines) {
                SettingsView()
                    .environmentObject(phoneSession)
            }
            .sheet(isPresented: $showStatistics) {
                StatisticsView()
            }
            .task { reloadQuarantines() }
        }
    }

    /// True while any Quarantined Store still holds matches missing from the
    /// live Match History — the notice disappears once nothing restorable
    /// remains.
    private var restorableMatchesExist: Bool {
        let liveIDs = Set(allMatches.map(\.id))
        return quarantines.contains { !$0.missingMatchIDs(from: liveIDs).isEmpty }
    }

    private func reloadQuarantines() {
        quarantines = StoreRecovery.listQuarantinedStores(in: LiveStore.directory)
    }

    private var restoreNotice: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue))

                Text("Old matches can be restored")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
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
        case "beachTennis": return String(localized: "Beach Tennis")
        case "tennis":      return String(localized: "Tennis")
        default:            return String(localized: "All")
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
        List {
            ForEach(matches) { match in
                NavigationLink(destination: MatchDetailView(match: match)) {
                    MatchRowView(match: match)
                }
            }
            .onDelete(perform: deleteMatches)
        }
        .listStyle(.insetGrouped)
    }

    private func deleteMatches(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(matches[index])
        }
        try? modelContext.save()
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
                // Plain String, not a literal — a user-entered Team Name must
                // never go through String Catalog lookup.
                Text(match.scoreLineDisplay)
                    .font(.headline)
            }

            Spacer()

            // No recognizable winner (a corrupt stored value) leaves nothing to
            // name — drop the capsule rather than badge a bare "wins".
            if !match.winnerDisplayName.isEmpty {
                winnerBadge
            }
        }
        .padding(.vertical, 4)
    }

    private var sportBadge: some View {
        Text(match.matchType == .tennis ? String(localized: "Tennis") : "Beach")
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
        Text("\(match.winnerDisplayName) wins")
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.orange))
    }
}
