# Plan 003: Deduplicate match results with an idempotency key

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5497f0b..HEAD -- BeachTennisCounter/Shared/WatchMessage.swift BeachTennisCounter/watchOS/Services/WatchSessionManager.swift BeachTennisCounter/iOS/Services/PhoneSessionManager.swift BeachTennisCounter/Tests/MatchResultPayloadTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/001-ci-verification-baseline.md (test command). Must land **before** plans/004 (both edit `WatchMessage.swift` + `WatchSessionManager.swift`).
- **Category**: bug
- **Planned at**: commit `5497f0b`, 2026-07-12
- **Issue**: https://github.com/renan002/beach-tennis-score/issues/4

## Why this matters

When a match ends, the watch sends the result via `WCSession.sendMessage` and, if the error handler fires, falls back to `transferUserInfo`. The iPhone inserts a `StoredMatch` from **both** `didReceiveMessage` and `didReceiveUserInfo`, with no deduplication. `sendMessage` can report an error (e.g. a reply timeout) even when the message was actually delivered — in that case the fallback `transferUserInfo` delivers a second copy and the user sees the same match twice in their history. The payload has no stable ID to dedup on (`StoredMatch.id` is generated on the phone at insert time). This plan adds a `matchId` generated on the watch and makes the phone-side insert idempotent.

## Current state

- `BeachTennisCounter/Shared/WatchMessage.swift` — `WatchMessageKey` constants (lines 3-18), `MatchResultPayload` struct with `toDictionary()` (37-56) and `static func from(_:)` (58-98). No ID field.
- `BeachTennisCounter/watchOS/Services/WatchSessionManager.swift:21-45` — `sendMatchResult(_:duration:)` builds the payload and sends:

```swift
// WatchSessionManager.swift:37-44
let dict = payload.toDictionary()
if WCSession.default.isReachable {
    WCSession.default.sendMessage(dict, replyHandler: nil) { _ in
        WCSession.default.transferUserInfo(dict)
    }
} else {
    WCSession.default.transferUserInfo(dict)
}
```

- `BeachTennisCounter/iOS/Services/PhoneSessionManager.swift:72-103` — both delegate callbacks funnel into `insertMatch(from:)`:

```swift
// PhoneSessionManager.swift:80-102 (abridged)
private nonisolated func insertMatch(from dict: [String: Any]) {
    guard dict[WatchMessageKey.type] as? String == WatchMessageType.matchResult,
          let payload = MatchResultPayload.from(dict) else { return }
    Task { @MainActor in
        guard let context = modelContext else { return }
        ...
        let match = StoredMatch(
            date: payload.date, ...
        )
        context.insert(match)
        try? context.save()
    }
}
```

- `BeachTennisCounter/iOS/Models/StoredMatch.swift:5-17` — SwiftData `@Model` with `var id: UUID` (defaulted to `UUID()` in `init`). **Do not add `@Attribute(.unique)`**: a schema change risks triggering the destructive migration fallback in `BeachTennisApp.makeContainer()` (`iOS/BeachTennisApp.swift:18-34` deletes the store on migration failure). Dedup must be a fetch-before-insert check, not a schema constraint.
- `BeachTennisCounter/Tests/MatchResultPayloadTests.swift` — round-trip and missing-field tests for the payload; follow its `makePayload(...)` helper pattern.
- Swift 6 concurrency convention (from `CLAUDE.md`): WCSession delegate callbacks are `nonisolated`; extract `Sendable` values before `Task { @MainActor in }`. `UUID` is `Sendable`, so passing the payload into the existing Task is unchanged.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Watch-only compile check | `cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build` | `** BUILD SUCCEEDED **` |
| Run tests | see "Verified commands" in `plans/README.md` (from plan 001) | `** TEST SUCCEEDED **` |

No new files are added, so `xcodegen generate` is not required.

## Scope

**In scope** (the only files you should modify):
- `BeachTennisCounter/Shared/WatchMessage.swift`
- `BeachTennisCounter/watchOS/Services/WatchSessionManager.swift`
- `BeachTennisCounter/iOS/Services/PhoneSessionManager.swift`
- `BeachTennisCounter/Tests/MatchResultPayloadTests.swift`

**Out of scope** (do NOT touch):
- `BeachTennisCounter/iOS/Models/StoredMatch.swift` — no schema change (see the destructive-migration note above).
- `BeachTennisCounter/iOS/BeachTennisApp.swift` — the migration fallback is out of scope.
- The retry/queueing behavior of `sendMatchResult` — that is plan 004.

## Git workflow

- Branch: `advisor/003-match-result-idempotency`
- Commit style: `fix(sync): dedupe match results with a watch-generated matchId`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add `matchId` to the payload

In `BeachTennisCounter/Shared/WatchMessage.swift`:

1. Add to `WatchMessageKey`: `static let matchId = "matchId"`.
2. Add to `MatchResultPayload`: `let matchId: UUID` (place it first among the stored properties).
3. In `toDictionary()`, add `WatchMessageKey.matchId: matchId.uuidString` to the base dictionary.
4. In `from(_:)`, decode it tolerantly (legacy payloads without an ID must still parse):

```swift
let matchId = (dict[WatchMessageKey.matchId] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
```

and pass `matchId: matchId` into the returned payload. Note: a legacy payload gets a *fresh* UUID and therefore is never dropped by dedup — that is the intended fail-open behavior.

**Verify**: `cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build` → fails listing the missing `matchId:` argument in `WatchSessionManager.swift` (expected — fixed in Step 2). If it fails anywhere else, fix that first.

### Step 2: Generate the ID on the watch

In `BeachTennisCounter/watchOS/Services/WatchSessionManager.swift`, in `sendMatchResult(_:duration:)`, add `matchId: UUID(),` as the first argument of the `MatchResultPayload(...)` initializer call (around line 25).

**Verify**: watch-only build → `** BUILD SUCCEEDED **`.

### Step 3: Make the phone insert idempotent

In `BeachTennisCounter/iOS/Services/PhoneSessionManager.swift`, add `import SwiftData` awareness is already present (line 4). Inside `insertMatch`'s `Task { @MainActor in }`, after the `guard let context` line and before building `StoredMatch`, add:

```swift
let matchId = payload.matchId
let existing = FetchDescriptor<StoredMatch>(
    predicate: #Predicate { $0.id == matchId }
)
if let count = try? context.fetchCount(existing), count > 0 { return }
```

Then pass the ID into the model: change the `StoredMatch(` call to start with `id: payload.matchId,`  (the `init` already accepts `id:` with a default — see `StoredMatch.swift:19`).

**Verify**: run the full test suite (or `build-for-testing` under the CI-only fallback) → succeeds. Note: `#Predicate` requires the captured value to be a local constant (`matchId`), not a key-path into `payload` — keep the local.

### Step 4: Extend the payload tests

In `BeachTennisCounter/Tests/MatchResultPayloadTests.swift`:

1. Update the `makePayload` helper to accept `matchId: UUID = UUID()` and pass it through.
2. Add `test_roundtrip_matchId` — encode via `toDictionary()`, decode via `from(_:)`, assert `decoded?.matchId == payload.matchId`.
3. Add `test_from_missingMatchIdStillDecodes` — remove `WatchMessageKey.matchId` from the dict, assert `MatchResultPayload.from(dict)` is non-nil.
4. Add `test_from_invalidMatchIdStillDecodes` — set `dict[WatchMessageKey.matchId] = "not-a-uuid"`, assert non-nil result.

**Verify**: test command → `** TEST SUCCEEDED **`, including the 3 new tests.

## Test plan

Covered by Step 4 (payload round-trip + tolerant decoding). The phone-side dedup fetch is exercised only at runtime (the test target has no SwiftData harness today); adding a SwiftData in-memory test is explicitly deferred — note it in your report. Pattern to follow: existing tests in `MatchResultPayloadTests.swift`.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -n "matchId" BeachTennisCounter/Shared/WatchMessage.swift` → key constant, property, encode, and decode sites all present
- [ ] `grep -n "fetchCount\|#Predicate" BeachTennisCounter/iOS/Services/PhoneSessionManager.swift` → dedup check present in `insertMatch`
- [ ] `grep -n "@Attribute" BeachTennisCounter/iOS/Models/StoredMatch.swift` → **no matches** (no schema change)
- [ ] Watch-only build → `** BUILD SUCCEEDED **`
- [ ] Test command → `** TEST SUCCEEDED **` with ≥ 3 new payload tests
- [ ] `git status` shows changes only to the 4 in-scope files
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The `#Predicate` fetch on `StoredMatch.id` fails to compile against this SwiftData version after one reasonable fix attempt (e.g. moving the UUID into a local) — report the compiler error rather than switching to a fetch-all-and-filter approach without sign-off.
- You find yourself wanting to modify `StoredMatch.swift` or add `@Attribute(.unique)` — that path risks user data loss via the destructive migration fallback.
- The excerpts in "Current state" don't match the live code.

## Maintenance notes

- Plan 004 edits `sendMatchResult` and `WatchMessage.swift` next — execute 003 before 004 to avoid conflicts.
- Watch and phone must ship together for dedup to work end-to-end; a legacy watch build talking to a new phone build simply gets no dedup (fail-open, no crash).
- Reviewer focus: the `#Predicate` local-capture rule, and that `from(_:)` never returns nil solely because `matchId` is absent.
- Deferred: an in-memory SwiftData test harness for `PhoneSessionManager.insertMatch` (would also let plan 004's queue logic be tested); worth its own small plan if sync bugs recur.
