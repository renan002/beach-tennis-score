import SwiftUI
import SwiftData

/// The Match History section of Settings: every Quarantined Store, newest
/// first, with Restore and Discard. Thin consumer of `StoreRecovery` — all
/// file and store work lives there. The parent owns the listing (and reloads
/// it via `reload`) because this section renders nothing while no quarantine
/// exists, so it cannot host its own `.task`.
struct QuarantinedStoresSection: View {
    let quarantines: [QuarantinedStore]
    let liveMatchIDs: Set<UUID>
    let reload: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var discardTarget: QuarantinedStore?
    @State private var showDiscardFailed = false
    @State private var showRestoreResult = false
    /// nil while `showRestoreResult` means the restore failed.
    @State private var restoredCount: Int?

    var body: some View {
        Section {
            ForEach(quarantines) { store in
                row(for: store)
            }
        } header: {
            Text("Match History")
        } footer: {
            Text("Match History the app couldn't open is kept here, set aside intact. Restore adds its matches back without changing the ones you already have.")
        }
        .confirmationDialog(
            discardTitle,
            isPresented: Binding(
                get: { discardTarget != nil },
                set: { if !$0 { discardTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                if let target = discardTarget {
                    do {
                        try StoreRecovery.discard(target.directory)
                    } catch {
                        showDiscardFailed = true
                    }
                    reload()
                }
            }
        } message: {
            discardMessage
        }
        .alert(Text("Discard failed"), isPresented: $showDiscardFailed) {} message: {
            Text("The Quarantined Store was not removed.")
        }
        .alert(
            restoredCount == nil ? Text("Restore failed") : Text("Restore complete"),
            isPresented: $showRestoreResult
        ) {} message: {
            if let count = restoredCount {
                Text("\(count) matches restored.")
            } else {
                Text("Your Match History was not changed.")
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(for store: QuarantinedStore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.quarantinedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline.weight(.semibold))

            switch store.contents {
            case .readable(let matchIDs):
                let missing = store.missingMatchIDs(from: liveMatchIDs)
                HStack(spacing: 6) {
                    Text("\(matchIDs.count) matches")
                    if missing.isEmpty {
                        Label("Restored", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("·").foregroundStyle(.secondary)
                        Text("\(missing.count) can be restored")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    if !missing.isEmpty {
                        Button("Restore") { restore(store) }
                            .buttonStyle(.borderedProminent)
                    }
                    Button("Discard", role: .destructive) { discardTarget = store }
                        .buttonStyle(.bordered)
                }
            case .unreadable:
                Text("Can't be read by this version of the app")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("It may become readable after an app update.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Discard", role: .destructive) { discardTarget = store }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Discard dialog copy

    /// What a Discard would actually cost the player: only the matches not
    /// yet in the live Match History. Empty means nothing would be lost —
    /// either the store is fully restored, or it is unreadable and the loss
    /// is unknowable.
    private var discardWouldLose: Set<UUID> {
        discardTarget?.missingMatchIDs(from: liveMatchIDs) ?? []
    }

    private var discardTitle: Text {
        if discardWouldLose.isEmpty {
            return Text("Discard this Quarantined Store?")
        }
        return Text("Discard \(discardWouldLose.count) matches?")
    }

    private var discardMessage: Text {
        switch discardTarget?.contents {
        case .readable where discardWouldLose.isEmpty:
            return Text("All of its matches are already in your Match History.")
        case .readable:
            return Text("They will be permanently deleted.")
        default:
            return Text("Its matches will be permanently deleted.")
        }
    }

    // MARK: - Actions

    private func restore(_ store: QuarantinedStore) {
        do {
            restoredCount = try StoreRecovery.restore(
                from: store.directory, into: modelContext.container)
        } catch {
            restoredCount = nil
        }
        showRestoreResult = true
        reload()
    }
}
