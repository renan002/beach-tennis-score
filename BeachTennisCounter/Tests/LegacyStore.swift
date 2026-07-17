import Foundation
import SwiftData
@testable import BeachTennisCounter

// A faithful reconstruction of the 1.1.x on-disk schema for `StoredMatch`: the
// attributes the app shipped before Tennis mode (`ca652a9`) added
// setHistoryData, matchTypeRaw, setsWonA and setsWonB. `gameHistoryData`
// predates Tennis mode (it is present in `ca652a9^`), so it belongs here — the
// migration-breaking delta is specifically setsWonA/setsWonB, the added
// non-optional Ints that #47 gives property-level defaults.
//
// SwiftData derives a store's entity name from the simple class name, so
// declaring this `StoredMatch` (file-private, distinct from the app's
// `BeachTennisCounter.StoredMatch`) produces a store that lightweight migration
// treats as the same entity — the same schema delta a 1.1.x upgrader has on
// disk, without the manual step of recording the real 1.1.0 tag build.
//
// This type is never referenced outside this file; the seam under test opens
// the store it writes through the app's current `StoredMatch`.
@Model
private final class StoredMatch {
    var id: UUID
    var date: Date
    var setScoreA: Int
    var setScoreB: Int
    var winner: String
    var duration: TimeInterval
    var gameHistoryData: Data = Data()

    init(id: UUID, date: Date, setScoreA: Int, setScoreB: Int, winner: String, duration: TimeInterval) {
        self.id = id
        self.date = date
        self.setScoreA = setScoreA
        self.setScoreB = setScoreB
        self.winner = winner
        self.duration = duration
    }
}

/// A completed match as the 1.1.x app would have recorded it.
struct LegacyMatch {
    let id: UUID
    let date: Date
    let setScoreA: Int
    let setScoreB: Int
    let winner: String
    let duration: TimeInterval
}

/// Writes a 1.1.x-schema store to `directory/default.store`, flushed to disk,
/// so a later open through the current schema exercises real lightweight
/// migration against the exact attribute delta 1.1.x upgraders hit.
enum LegacyStore {
    static func write(_ matches: [LegacyMatch], to directory: URL) throws {
        let configuration = ModelConfiguration(url: directory.appending(path: LiveStore.storeName))
        let container = try ModelContainer(for: StoredMatch.self, configurations: configuration)
        let context = ModelContext(container)
        for m in matches {
            context.insert(StoredMatch(
                id: m.id, date: m.date,
                setScoreA: m.setScoreA, setScoreB: m.setScoreB,
                winner: m.winner, duration: m.duration))
        }
        try context.save()
    }
}
