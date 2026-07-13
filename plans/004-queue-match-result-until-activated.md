# Plan 004: Stop silently dropping match results when the session isn't activated

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5497f0b..HEAD -- BeachTennisCounter/Shared/WatchMessage.swift BeachTennisCounter/watchOS/Services/WatchSessionManager.swift`
> Plan 003 intentionally modifies both files first — that is expected drift.
> Confirm plan 003's changes are present (a `matchId` property exists on
> `MatchResultPayload`); any *other* structural drift from the excerpts below
> is a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/003-match-result-idempotency.md (same files; also, retrying delivery without dedup could itself create duplicates)
- **Category**: bug
- **Planned at**: commit `5497f0b`, 2026-07-12
- **Issue**: https://github.com/renan002/beach-tennis-score/issues/4

## Why this matters

At match end, `WatchSessionManager.sendMatchResult` starts with `guard WCSession.default.activationState == .activated ... else { return }`. If the session isn't activated at that moment, the finished match — the one thing this app exists to record — is silently and permanently lost. It's a rare window (activation starts at app launch), but the failure mode is unrecoverable data loss with zero feedback. The fix: persist the pending payload on the watch and flush it when activation completes.

## Current state

- `BeachTennisCounter/watchOS/Services/WatchSessionManager.swift` — `@MainActor` singleton, activates `WCSession` in `init` (lines 13-19). As of `5497f0b`:

```swift
// WatchSessionManager.swift:21-23
func sendMatchResult(_ state: MatchState, duration: TimeInterval) {
    guard WCSession.default.activationState == .activated,
          let winner = state.winner else { return }
```

```swift
// WatchSessionManager.swift:55-66 — activation callback (nonisolated)
nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: (any Error)?
) {
    let context = session.receivedApplicationContext
    guard !context.isEmpty else { return }
    ... // applies colors via Task { @MainActor in ... }
}
```

(After plan 003, the payload also carries `matchId` — keep that.)

- `BeachTennisCounter/Shared/WatchMessage.swift` — `MatchResultPayload` is a plain `Sendable` struct whose members are all `Codable` types (`UUID`, `Int`, `Team`, `TimeInterval`, `Date`, `[GameRecord]`, `[SetRecord]`, `MatchType`), but the struct itself is **not** declared `Codable`. It converts to/from `[String: Any]` via `toDictionary()` / `from(_:)`.
- Caller: `watchOS/Views/ScoreView.swift:42-46` calls `sendMatchResult` once, from `onChange(of: state.isMatchOver)`. There is no retry anywhere.
- Swift 6 convention (from `CLAUDE.md`): delegate callbacks are `nonisolated`; extract `Sendable` values before hopping to `Task { @MainActor in }`. `UserDefaults` is safe to call from any thread.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Watch-only build (primary gate — all edits are watch/Shared code) | `cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build` | `** BUILD SUCCEEDED **` |
| Run tests | see "Verified commands" in `plans/README.md` (from plan 001) | `** TEST SUCCEEDED **` |

No new files → no `xcodegen generate` needed.

## Scope

**In scope** (the only files you should modify):
- `BeachTennisCounter/Shared/WatchMessage.swift` (add `Codable` conformance only)
- `BeachTennisCounter/watchOS/Services/WatchSessionManager.swift`
- `BeachTennisCounter/Tests/MatchResultPayloadTests.swift` (one round-trip test for Codable)

**Out of scope** (do NOT touch):
- `BeachTennisCounter/iOS/Services/PhoneSessionManager.swift` — phone side is already idempotent after plan 003.
- `watchOS/Views/ScoreView.swift` — the call site is fine; the fix belongs in the manager.
- Any UI for "pending sync" state — deliberately deferred.

## Git workflow

- Branch: `advisor/004-queue-match-result`
- Commit style: `fix(sync): queue match result until WCSession activates`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Make `MatchResultPayload` Codable

In `BeachTennisCounter/Shared/WatchMessage.swift`, change the declaration to:

```swift
struct MatchResultPayload: Codable, Sendable {
```

All stored properties are already `Codable`, so no other change is needed. The dictionary encoding (`toDictionary`/`from`) stays as the wire format for WatchConnectivity; `Codable` is only for local persistence of a pending payload.

**Verify**: watch-only build → `** BUILD SUCCEEDED **`.

### Step 2: Persist the payload instead of dropping it

In `BeachTennisCounter/watchOS/Services/WatchSessionManager.swift`:

1. Add a private constant on the class: `private static let pendingResultKey = "pendingMatchResult"`.
2. Restructure `sendMatchResult` so the payload is built **before** the activation check, and an inactive session stores instead of returning:

```swift
func sendMatchResult(_ state: MatchState, duration: TimeInterval) {
    guard let winner = state.winner else { return }
    let payload = MatchResultPayload(... as today, including matchId: UUID() ...)

    guard WCSession.default.activationState == .activated else {
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: Self.pendingResultKey)
        }
        return
    }
    deliver(payload)
}

private func deliver(_ payload: MatchResultPayload) {
    let dict = payload.toDictionary()
    if WCSession.default.isReachable {
        WCSession.default.sendMessage(dict, replyHandler: nil) { _ in
            WCSession.default.transferUserInfo(dict)
        }
    } else {
        WCSession.default.transferUserInfo(dict)
    }
}
```

(The `deliver` body is today's lines 37-44, moved verbatim.)

**Verify**: watch-only build → `** BUILD SUCCEEDED **`.

### Step 3: Flush the pending payload on activation

Still in `WatchSessionManager.swift`, add a flush to the existing `nonisolated` activation callback. Do the UserDefaults read and the send inside the callback **before** the existing early-return on empty application context (the current `guard !context.isEmpty else { return }` must not skip the flush):

```swift
nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: (any Error)?
) {
    if activationState == .activated,
       let data = UserDefaults.standard.data(forKey: Self.pendingResultKey),
       let payload = try? JSONDecoder().decode(MatchResultPayload.self, from: data) {
        UserDefaults.standard.removeObject(forKey: Self.pendingResultKey)
        WCSession.default.transferUserInfo(payload.toDictionary())
    }

    let context = session.receivedApplicationContext
    guard !context.isEmpty else { return }
    ...existing color-extraction code unchanged...
}
```

Notes:
- `transferUserInfo` is the right delivery path here (queued, survives reachability changes); do not use `sendMessage` from this callback.
- Everything used here (`UserDefaults`, `JSONDecoder`, `WCSession.default.transferUserInfo`) is callable from the `nonisolated` context; no `@MainActor` hop is needed for the flush. Because plan 003's dedup uses `matchId`, a payload that was *both* stored and somehow delivered can't double-insert on the phone.

**Verify**: watch-only build → `** BUILD SUCCEEDED **`.

### Step 4: Add a Codable round-trip test

In `BeachTennisCounter/Tests/MatchResultPayloadTests.swift`, add:

```swift
func test_codableRoundtrip_preservesFields() {
    let payload = makePayload(setScoreA: 7, setScoreB: 6, winner: .b, duration: 1234)
    let data = try! JSONEncoder().encode(payload)
    let decoded = try! JSONDecoder().decode(MatchResultPayload.self, from: data)
    XCTAssertEqual(decoded.matchId, payload.matchId)
    XCTAssertEqual(decoded.setScoreA, 7)
    XCTAssertEqual(decoded.setScoreB, 6)
    XCTAssertEqual(decoded.winner, .b)
    XCTAssertEqual(decoded.duration, 1234, accuracy: 0.001)
}
```

**Verify**: test command → `** TEST SUCCEEDED **` including the new test.

## Test plan

- New test: `test_codableRoundtrip_preservesFields` in `MatchResultPayloadTests.swift` (Step 4), following that file's existing `makePayload` pattern.
- The store/flush path itself has no unit-test seam (it touches `WCSession.default` directly); manual QA note for the operator: force-quit the watch app, relaunch, finish a match immediately — the result should appear on the phone. Testable-seam refactor is deferred (see Maintenance notes).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -n "Codable" BeachTennisCounter/Shared/WatchMessage.swift` → `MatchResultPayload: Codable, Sendable`
- [ ] `grep -n "pendingMatchResult" BeachTennisCounter/watchOS/Services/WatchSessionManager.swift` → key constant + store site + flush site (≥ 3 matches)
- [ ] `grep -n "guard WCSession.default.activationState == .activated,$" BeachTennisCounter/watchOS/Services/WatchSessionManager.swift` → no match (the old combined drop-guard is gone)
- [ ] Watch-only build → `** BUILD SUCCEEDED **`
- [ ] Test command → `** TEST SUCCEEDED **`
- [ ] `git status` shows changes only to the 3 in-scope files
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- Plan 003 has not landed (no `matchId` on `MatchResultPayload`) — executing this first reorders the dependency and re-opens the duplicate-insert window.
- Adding `Codable` to `MatchResultPayload` produces compiler errors (would mean a member type lost `Codable` since `5497f0b`).
- Swift 6 concurrency errors in the activation callback survive one reasonable fix attempt — report the exact diagnostic instead of sprinkling `@unchecked Sendable` or `nonisolated(unsafe)`.

## Maintenance notes

- Single-slot queue by design: a second match finished while the first is still pending overwrites it. With activation completing within seconds of launch, two unsent matches in the window is not realistic; if it ever is, upgrade the slot to an array.
- Reviewer focus: the flush must run before the `receivedApplicationContext` early-return, and only when `activationState == .activated`.
- Deferred: extracting a `WCSession`-protocol seam so store/flush becomes unit-testable (pairs with the deferred SwiftData harness noted in plan 003).
