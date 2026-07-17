# Plan 014: Make the WatchConnectivity delivery guarantees unit-testable and test them

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9d05103..HEAD -- BeachTennisCounter/iOS/Services/PhoneSessionManager.swift BeachTennisCounter/watchOS/Services/WatchSessionManager.swift BeachTennisCounter/Shared BeachTennisCounter/Tests`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests (testability + coverage)
- **Planned at**: commit `9d05103`, 2026-07-17

## Why this matters

The two guarantees that keep the phone's Match History correct across the
watch→phone hop are **the phone deduplicating on `matchId`** (a match already
stored is never inserted twice) and **the watch queueing a result until its
`WCSession` activates** (a match finished before the session is ready is not
lost). Both were built deliberately (issue #4, plans 003/004). Yet neither has
a unit test: the logic lives inside `@MainActor` singleton delegate callbacks
that touch live `WCSession`/`UserDefaults`/SwiftData, so nothing exercises it —
only the payload's dictionary round-trip is tested (`MatchResultPayloadTests`).
A future refactor of either manager could silently drop dedup (→ duplicate
matches in history) or drop the queue (→ lost matches) and every test would
still pass.

This repo already has the pattern for making exactly this kind of logic
testable: `Shared/MatchPersistence.swift` is a pure `enum` with
`save`/`load`/`clear(in: UserDefaults)` that `WatchSessionManager` calls and
`MatchPersistenceTests` covers; `StoreRecovery.restore(from:into:)` is a pure
static that takes a `ModelContainer` and is covered by
`StoreRecoveryRestoreTests`. This plan extracts the two delivery decisions into
the same shape and tests them, leaving the singletons as thin callers.

## Current state

### Phone-side dedup — `BeachTennisCounter/iOS/Services/PhoneSessionManager.swift:73-102`

```swift
    private nonisolated func insertMatch(from dict: [String: Any]) {
        guard dict[WatchMessageKey.type] as? String == WatchMessageType.matchResult,
              let payload = MatchResultPayload.from(dict) else { return }

        Task { @MainActor in
            guard let context = modelContext else { return }
            let matchId = payload.matchId
            let existing = FetchDescriptor<StoredMatch>(
                predicate: #Predicate { $0.id == matchId }
            )
            if let count = try? context.fetchCount(existing), count > 0 { return }
            let gameData = (try? JSONEncoder().encode(payload.gameHistory)) ?? Data()
            let setData = (try? JSONEncoder().encode(payload.setHistory)) ?? Data()
            let match = StoredMatch(
                id: payload.matchId,
                date: payload.date,
                setScoreA: payload.setScoreA,
                setScoreB: payload.setScoreB,
                setsWonA: payload.setsWonA,
                setsWonB: payload.setsWonB,
                winner: payload.winner.rawValue,
                duration: payload.duration,
                gameHistoryData: gameData,
                setHistoryData: setData,
                matchTypeRaw: payload.matchType.rawValue
            )
            context.insert(match)
            try? context.save()
        }
    }
```

The dedup + insert (everything inside the `Task { @MainActor in … }`) is the
pure decision worth testing. The `nonisolated` guard/decode and the `Task` hop
are WatchConnectivity plumbing that stays in the manager.

### Watch-side pending queue — `BeachTennisCounter/watchOS/Services/WatchSessionManager.swift`

`pendingResultKey` and the queue/flush logic (lines 13, 40-47, 73-78):

```swift
    private nonisolated static let pendingResultKey = "pendingMatchResult"
    // …
    func sendMatchResult(_ state: MatchState, duration: TimeInterval) {
        guard let winner = state.winner else { return }
        let payload = MatchResultPayload( … )        // (unchanged; builds the payload)

        guard WCSession.default.activationState == .activated else {
            if let data = try? JSONEncoder().encode(payload) {
                UserDefaults.standard.set(data, forKey: Self.pendingResultKey)
            }
            return
        }
        deliver(payload)
    }
    // … in activationDidCompleteWith:
        if activationState == .activated,
           let data = UserDefaults.standard.data(forKey: Self.pendingResultKey),
           let payload = try? JSONDecoder().decode(MatchResultPayload.self, from: data) {
            UserDefaults.standard.removeObject(forKey: Self.pendingResultKey)
            WCSession.default.transferUserInfo(payload.toDictionary())
        }
```

The encode-to-defaults / decode-from-defaults / remove is the pure queue; the
`activationState`/`WCSession` checks are plumbing that stays.

### Conventions to match (inline — the executor has not read these)

- **Pure logic as a static-method `enum`, injectable dependencies.**
  `Shared/MatchPersistence.swift` is the exemplar: `enum MatchPersistence` with
  `static func save(_:in defaults: UserDefaults = .standard, now: Date = Date())`,
  `load`, `clear`. `UserDefaults` is a parameter with a `.standard` default so
  tests pass a scratch suite.
- **Where a file must live to be testable.** The test target
  (`BeachTennisCounterTests`) is an **iOS** target that depends on the iOS app
  target (`project.yml`). Files under `Shared/` and under `iOS/` are compiled
  into it and are testable via `@testable import BeachTennisCounter`. **Files
  under `watchOS/` are NOT in the test target** — so the watch queue must be
  extracted into `Shared/`, next to `MatchPersistence` (it already depends only
  on `MatchResultPayload`, which is in `Shared/`). The phone helper stays in
  `iOS/` (already testable).
- **Test file shape.** XCTest, `@testable import BeachTennisCounter`. For
  UserDefaults tests, model after `Tests/MatchPersistenceTests.swift` (scratch
  suite per test via `UserDefaults(suiteName: "…-\(UUID())")`, torn down with
  `removePersistentDomain`). For SwiftData tests, model after
  `Tests/StoreRecoveryRestoreTests.swift` (build a `ModelContainer` with an
  explicit `ModelConfiguration`, insert via a `ModelContext`, fetch to assert).
- **Build convention (`CLAUDE.md`).** After adding any `.swift` file, run
  `cd BeachTennisCounter && xcodegen generate` — the `.xcodeproj` does not pick
  up new files automatically.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Regenerate project after adding files | `cd BeachTennisCounter && xcodegen generate` | `Generated project at .../BeachTennisCounter.xcodeproj` |
| Run tests | `cd BeachTennisCounter && xcodebuild test -project BeachTennisCounter.xcodeproj -scheme BeachTennisCounter -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |

If `iPhone 17` is unavailable, substitute any device from
`xcrun simctl list devices available`. CI runs the same tests and is the
authoritative gate.

## Scope

**In scope** (the only files you should modify/create):
- `BeachTennisCounter/Shared/PendingMatchResult.swift` (create — the watch queue)
- `BeachTennisCounter/watchOS/Services/WatchSessionManager.swift` (route through
  the new type; no behavior change)
- `BeachTennisCounter/iOS/Services/PhoneSessionManager.swift` (extract the
  dedup+insert into a testable static; call it)
- `BeachTennisCounter/Tests/PendingMatchResultTests.swift` (create)
- `BeachTennisCounter/Tests/MatchInboxTests.swift` (create)
- `BeachTennisCounter/BeachTennisCounter.xcodeproj/*` (regenerated by xcodegen —
  do not hand-edit)

**Out of scope** (do NOT touch, even though they look related):
- The `WCSession` calls themselves (`sendMessage`, `transferUserInfo`,
  `updateApplicationContext`), `deliver(_:)`, and the settings/application-context
  paths — this plan does not change what gets sent or when, only where the
  encode/decode/dedup lives. No test may reference `WCSession`.
- `Shared/MatchResultPayload.swift` / `WatchMessage.swift` — the payload shape
  is unchanged.
- `StoredMatch.swift` schema — no new fields.
- `MatchPersistence.swift` — the in-progress-match queue is a different thing
  (see CONTEXT.md "Undo Stack"/persistence vs. this delivery queue); leave it.

## Git workflow

- Branch: `test/014-session-delivery-logic` (cut from `develop`, per `CLAUDE.md`).
- Commit style (Conventional Commits): e.g.
  `refactor(watch): extract pending match-result queue into Shared` and
  `test: cover watch pending-result queue and phone dedup`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

Order matters: add the new pure types and switch the callers, verify the build
is still green, then add tests. The app must compile after every step.

### Step 1: Create `Shared/PendingMatchResult.swift` (the watch delivery queue)

Create `BeachTennisCounter/Shared/PendingMatchResult.swift`. Mirror
`MatchPersistence`'s shape exactly (static enum, injectable `UserDefaults`):

```swift
import Foundation

/// A single match result the watch finished before its `WCSession` was
/// activated, held until activation so a completed match is never lost.
/// One slot: a newer pending result replaces an older one, which is safe
/// because the watch scores one match at a time and each result carries its
/// own `matchId` for the phone to dedup on.
///
/// The delivery-time counterpart to `MatchPersistence` (which holds the
/// *in-progress* match). This holds a *finished* result awaiting transfer.
enum PendingMatchResult {
    static let key = "pendingMatchResult"

    static func save(_ payload: MatchResultPayload, in defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: key)
    }

    static func load(in defaults: UserDefaults = .standard) -> MatchResultPayload? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MatchResultPayload.self, from: data)
    }

    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
```

Keep the storage key string identical to the current
`WatchSessionManager.pendingResultKey` value (`"pendingMatchResult"`) so any
result already queued on a user's watch under the old key is still found after
the update.

Run `cd BeachTennisCounter && xcodegen generate`.

**Verify**: `grep -n "enum PendingMatchResult" BeachTennisCounter/Shared/PendingMatchResult.swift` → 1 match; xcodegen exits 0.

### Step 2: Route `WatchSessionManager` through `PendingMatchResult`

In `BeachTennisCounter/watchOS/Services/WatchSessionManager.swift`:

1. Delete the line
   `private nonisolated static let pendingResultKey = "pendingMatchResult"`.
2. In `sendMatchResult`, replace the not-activated branch body:

   ```swift
   guard WCSession.default.activationState == .activated else {
       PendingMatchResult.save(payload)
       return
   }
   deliver(payload)
   ```
3. In `session(_:activationDidCompleteWith:error:)`, replace the pending-flush
   block with:

   ```swift
   if activationState == .activated, let payload = PendingMatchResult.load() {
       PendingMatchResult.clear()
       WCSession.default.transferUserInfo(payload.toDictionary())
   }
   ```

Do not change the settings/application-context code below it in that method.

**Verify**:
- `grep -n "pendingResultKey" BeachTennisCounter/watchOS/Services/WatchSessionManager.swift` → no output
- `grep -c "PendingMatchResult\." BeachTennisCounter/watchOS/Services/WatchSessionManager.swift` → `3`

### Step 3: Extract the phone dedup+insert into a testable static

In `BeachTennisCounter/iOS/Services/PhoneSessionManager.swift`, add a new
static method on the class and have `insertMatch` call it. The method holds the
dedup+insert; the manager keeps the decode + `Task` hop.

Add this method to `PhoneSessionManager` (e.g. just below `insertMatch`):

```swift
    /// Inserts a match for `payload` into `context` unless one with the same
    /// `matchId` is already present. Returns true iff a new match was inserted.
    /// The identity rule is `matchId`, matching watch→phone dedup and the
    /// Restore merge (see ADR-0003).
    @MainActor
    @discardableResult
    static func insertMatchIfNew(_ payload: MatchResultPayload, into context: ModelContext) -> Bool {
        let matchId = payload.matchId
        let existing = FetchDescriptor<StoredMatch>(
            predicate: #Predicate { $0.id == matchId }
        )
        if let count = try? context.fetchCount(existing), count > 0 { return false }

        let gameData = (try? JSONEncoder().encode(payload.gameHistory)) ?? Data()
        let setData = (try? JSONEncoder().encode(payload.setHistory)) ?? Data()
        context.insert(StoredMatch(
            id: payload.matchId,
            date: payload.date,
            setScoreA: payload.setScoreA,
            setScoreB: payload.setScoreB,
            setsWonA: payload.setsWonA,
            setsWonB: payload.setsWonB,
            winner: payload.winner.rawValue,
            duration: payload.duration,
            gameHistoryData: gameData,
            setHistoryData: setData,
            matchTypeRaw: payload.matchType.rawValue
        ))
        try? context.save()
        return true
    }
```

Then replace the body of the `Task { @MainActor in … }` inside `insertMatch`
with just:

```swift
        Task { @MainActor in
            guard let context = modelContext else { return }
            Self.insertMatchIfNew(payload, into: context)
        }
```

Leave the `nonisolated` guard/decode above the `Task` unchanged.

**Verify**:
- `grep -n "insertMatchIfNew" BeachTennisCounter/iOS/Services/PhoneSessionManager.swift` → 2 matches (definition + call)
- `grep -c "context.insert(" BeachTennisCounter/iOS/Services/PhoneSessionManager.swift` → `1` (only inside the new static)

### Step 4: Compile gate (no new tests yet)

Run the test command from "Commands you will need". It compiles both app
targets and runs the existing suite.

**Verify**: `** TEST SUCCEEDED **` — the existing tests still pass, proving the
refactor didn't change behavior.

### Step 5: Add `PendingMatchResultTests`

Create `BeachTennisCounter/Tests/PendingMatchResultTests.swift`, modeled on
`Tests/MatchPersistenceTests.swift` (scratch UserDefaults suite per test):

```swift
import XCTest
@testable import BeachTennisCounter

final class PendingMatchResultTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "PendingMatchResultTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func samplePayload(id: UUID = UUID()) -> MatchResultPayload {
        MatchResultPayload(
            matchId: id,
            setScoreA: 6, setScoreB: 4,
            setsWonA: 0, setsWonB: 0,
            winner: .a,
            duration: 123,
            date: Date(timeIntervalSince1970: 1_752_662_400),
            gameHistory: [],
            setHistory: [],
            matchType: .beachTennis
        )
    }

    func test_saveThenLoad_roundtripsPayload() {
        let id = UUID()
        PendingMatchResult.save(samplePayload(id: id), in: defaults)
        let loaded = PendingMatchResult.load(in: defaults)
        XCTAssertEqual(loaded?.matchId, id)
        XCTAssertEqual(loaded?.setScoreA, 6)
        XCTAssertEqual(loaded?.winner, .a)
    }

    func test_load_returnsNilWhenNothingQueued() {
        XCTAssertNil(PendingMatchResult.load(in: defaults))
    }

    func test_save_replacesOlderPendingResult() {
        let first = UUID(), second = UUID()
        PendingMatchResult.save(samplePayload(id: first), in: defaults)
        PendingMatchResult.save(samplePayload(id: second), in: defaults)
        XCTAssertEqual(PendingMatchResult.load(in: defaults)?.matchId, second)
    }

    func test_clear_removesQueuedResult() {
        PendingMatchResult.save(samplePayload(), in: defaults)
        PendingMatchResult.clear(in: defaults)
        XCTAssertNil(PendingMatchResult.load(in: defaults))
    }
}
```

Run `cd BeachTennisCounter && xcodegen generate` (new test file).

**Verify**: xcodegen exits 0;
`grep -c PendingMatchResultTests BeachTennisCounter/BeachTennisCounter.xcodeproj/project.pbxproj` → ≥ 1.

### Step 6: Add `MatchInboxTests` (phone dedup)

Create `BeachTennisCounter/Tests/MatchInboxTests.swift`, modeled on
`Tests/StoreRecoveryRestoreTests.swift` for the SwiftData container idiom. The
method under test is `@MainActor`, so mark the test class `@MainActor`.

```swift
import XCTest
import SwiftData
@testable import BeachTennisCounter

@MainActor
final class MatchInboxTests: XCTestCase {

    private func inMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: StoredMatch.self, configurations: config)
    }

    private func payload(id: UUID = UUID(), setScoreA: Int = 6) -> MatchResultPayload {
        MatchResultPayload(
            matchId: id,
            setScoreA: setScoreA, setScoreB: 4,
            setsWonA: 0, setsWonB: 0,
            winner: .a,
            duration: 60,
            date: Date(timeIntervalSince1970: 1_752_662_400),
            gameHistory: [], setHistory: [],
            matchType: .beachTennis
        )
    }

    private func count(in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<StoredMatch>())
    }

    func test_insertsNewMatch() throws {
        let context = ModelContext(try inMemoryContainer())
        let inserted = PhoneSessionManager.insertMatchIfNew(payload(), into: context)
        XCTAssertTrue(inserted)
        XCTAssertEqual(try count(in: context), 1)
    }

    func test_duplicateMatchId_isNotInsertedTwice() throws {
        let context = ModelContext(try inMemoryContainer())
        let id = UUID()
        XCTAssertTrue(PhoneSessionManager.insertMatchIfNew(payload(id: id), into: context))
        let second = PhoneSessionManager.insertMatchIfNew(payload(id: id, setScoreA: 7), into: context)
        XCTAssertFalse(second)
        XCTAssertEqual(try count(in: context), 1)
    }

    func test_differentMatchIds_bothInserted() throws {
        let context = ModelContext(try inMemoryContainer())
        XCTAssertTrue(PhoneSessionManager.insertMatchIfNew(payload(), into: context))
        XCTAssertTrue(PhoneSessionManager.insertMatchIfNew(payload(), into: context))
        XCTAssertEqual(try count(in: context), 2)
    }

    func test_insertedMatch_preservesPayloadFields() throws {
        let context = ModelContext(try inMemoryContainer())
        let id = UUID()
        PhoneSessionManager.insertMatchIfNew(payload(id: id), into: context)
        let stored = try XCTUnwrap(try context.fetch(FetchDescriptor<StoredMatch>()).first)
        XCTAssertEqual(stored.id, id)
        XCTAssertEqual(stored.setScoreA, 6)
        XCTAssertEqual(stored.winner, "a")
        XCTAssertEqual(stored.matchTypeRaw, "beachTennis")
    }
}
```

Run `cd BeachTennisCounter && xcodegen generate` again (new test file).

**Verify**: xcodegen exits 0;
`grep -c MatchInboxTests BeachTennisCounter/BeachTennisCounter.xcodeproj/project.pbxproj` → ≥ 1.

### Step 7: Full test gate

Run the test command again.

**Verify**: `** TEST SUCCEEDED **`, including the 4 new `PendingMatchResultTests`
and the 4 new `MatchInboxTests`.

## Test plan

- **New file `PendingMatchResultTests.swift`** (4 tests): round-trip a queued
  payload; `load` nil when empty; a second `save` replaces the first
  (single-slot); `clear` empties the slot. Pattern: `MatchPersistenceTests`.
- **New file `MatchInboxTests.swift`** (4 tests): a new `matchId` inserts; a
  duplicate `matchId` does not insert a second row (the dedup guarantee); two
  distinct ids both insert; an inserted row carries the payload's fields.
  Pattern: `StoreRecoveryRestoreTests` for the SwiftData container idiom.
- No test drives `WCSession` or the singletons directly — the seams are the two
  extracted pure types, which is the point of Steps 1 and 3.
- Verification: the test command → all pass, including 8 new tests.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -n "pendingResultKey" BeachTennisCounter/watchOS/Services/WatchSessionManager.swift` → no output
- [ ] `grep -c "PendingMatchResult\." BeachTennisCounter/watchOS/Services/WatchSessionManager.swift` → `3`
- [ ] `grep -c "context.insert(" BeachTennisCounter/iOS/Services/PhoneSessionManager.swift` → `1`
- [ ] Test command → `** TEST SUCCEEDED **`; the 8 new tests exist and pass
- [ ] `git status` shows changes only to in-scope files (plus the regenerated `.xcodeproj`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- Any "Current state" excerpt no longer matches the live code (the managers were
  refactored since this plan was written).
- After moving the queue to `Shared/` and running `xcodegen generate`, the
  **watch** target fails to compile because it can't see `PendingMatchResult` —
  it is in `Shared/`, which the watch target compiles; if it genuinely isn't
  visible, report rather than duplicating the type per target.
- The test target cannot see `PhoneSessionManager.insertMatchIfNew` via
  `@testable import` — do not move files between targets or loosen access to fix
  it; report instead.
- Swift 6 concurrency errors appear at the new `@MainActor static` boundary that
  you cannot resolve without changing what crosses an actor boundary (per
  `CLAUDE.md`, `MatchResultPayload` and `MatchState` are `Sendable`; `ModelContext`
  is not, which is why the method is `@MainActor` and the test class is
  `@MainActor`). If a fix would require making `ModelContext` cross actors,
  stop.
- The existing suite (Step 4) fails *before* you add any new test — that means
  the refactor changed behavior; revert and report.

## Maintenance notes

- `PendingMatchResult` and `MatchPersistence` are deliberately separate: one
  holds a *finished result awaiting transfer*, the other the *in-progress match*
  (CONTEXT.md distinguishes these). Don't merge them.
- If the watch ever needs to queue more than one result (e.g. offline for a long
  session), the single-slot design must change — and `PendingMatchResultTests`
  `test_save_replacesOlderPendingResult` is the test that will need revisiting.
- `insertMatchIfNew` is the single definition of the phone's dedup rule; if the
  identity rule ever changes (today it's `matchId`, consistent with ADR-0003's
  Restore merge), change it here and update `MatchInboxTests`.
- Reviewer should scrutinize: that Steps 2 and 3 changed *only* where the
  encode/decode/dedup lives, not *what* is sent or *when* — diff the managers and
  confirm no `WCSession` call moved.
