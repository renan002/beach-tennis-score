# Plan 011: Persist the in-progress match on the watch and offer resume

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5497f0b..HEAD -- BeachTennisCounter/Shared BeachTennisCounter/watchOS/Views/ScoreView.swift BeachTennisCounter/watchOS/Views/HomeView.swift BeachTennisCounter/Tests`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. (Plan 008 adds one
> `.environmentObject(...)` line to `ScoreView`'s history sheet — that exact
> change is expected drift, not a STOP.)

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none (soft: plan 001 for the test gate; coordinate with 008 — both edit `ScoreView.swift`, land serially)
- **Category**: direction
- **Planned at**: commit `5497f0b`, 2026-07-12
- **Issue**: https://github.com/renan002/beach-tennis-score/issues/11

## Why this matters

The live score exists only in SwiftUI `@State` on the watch. watchOS
aggressively terminates suspended apps, and beach tennis matches run long with
the wrist down between points — so a system termination mid-match silently
destroys the score of the app's core activity, with no recovery. `MatchState`
is already `Codable`, so persisting it after every point and offering
"Resume Match" on the home screen is cheap insurance for the exact scenario
this app exists for.

## Current state

- `BeachTennisCounter/watchOS/Views/ScoreView.swift:12-13` — the only copy of
  the score:

```swift
@State private var state: MatchState
@State private var history: [MatchState] = []
```

- `ScoreView.swift:18-29` — the init builds a fresh `MatchState` from
  `initialServer`/`matchType`:

```swift
init(initialServer: Team, matchType: MatchType, isActive: Binding<Bool>) {
    self.initialServer = initialServer
    self.matchType = matchType
    self._isActive = isActive
    var s = MatchState()
    s.matchType = matchType
    s.servingTeam = initialServer
    s.initialServer = initialServer
    s.tiebreakFirstServer = initialServer
    s.matchStartDate = Date()
    _state = State(initialValue: s)
}
```

- `ScoreView.swift:50-53` — the cancel path (`"End Match"` sets
  `isActive = false`); `ScoreView.swift:42-46` — the match-over path
  (`.onChange(of: state.isMatchOver)`); `ScoreView.swift:256-266` —
  `awardPoint`/`undoLast`, the only two mutation sites.
- `BeachTennisCounter/watchOS/Views/HomeView.swift` — one "New Match" button;
  navigation via `navigationDestination(isPresented:)` bindings
  (lines 40-46); flow dispatch in `handleNewMatch()` (lines 50-61).
- `MatchState` is `Codable, Sendable` (`Shared/MatchState.swift:72`) — no
  encoding work needed.
- **Target membership fact that dictates file placement**: the unit-test
  target compiles against the iOS app target only (`project.yml:22-32`), and
  iOS builds `iOS/ + Shared/`. Code in `watchOS/` is untestable by the
  existing suite — so the persistence helper must live in `Shared/`
  (convention there: UI-free logic in static-method `enum`s, see
  `ScoreEngine.swift`).
- Test conventions: XCTest, `@testable import BeachTennisCounter`, setup/
  teardown pattern — see `Tests/PointScoreTests.swift` for the minimal shape.
- Build-system convention (`CLAUDE.md`): after adding any `.swift` file, run
  `cd BeachTennisCounter && xcodegen generate`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Regenerate project after adding files | `cd BeachTennisCounter && xcodegen generate` | `Generated project at .../BeachTennisCounter.xcodeproj` |
| Watch-only build (fast gate) | `cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build` | `** BUILD SUCCEEDED **` |
| Full test gate | see "Verified commands" in `plans/README.md` (from plan 001) | `** TEST SUCCEEDED **` |

## Scope

**In scope** (the only files you should modify/create):
- `BeachTennisCounter/Shared/MatchPersistence.swift` (create)
- `BeachTennisCounter/watchOS/Views/ScoreView.swift`
- `BeachTennisCounter/watchOS/Views/HomeView.swift`
- `BeachTennisCounter/Tests/MatchPersistenceTests.swift` (create)
- `BeachTennisCounter/BeachTennisCounter.xcodeproj/*` (regenerated — do not hand-edit)

**Out of scope** (do NOT touch):
- Persisting the **undo stack** — a resumed match starts with empty undo
  history; deliberate scope cut (see Maintenance notes).
- `WatchSessionManager.swift` / any WCSession code — this is local-only
  persistence, nothing syncs to the phone until the match ends as today.
- `ScoreEngine.swift`, `MatchState.swift` — no model/engine changes; the
  state is persisted as-is.
- iCloud/app-group storage — plain `UserDefaults.standard` on the watch.

## Git workflow

- Branch: `advisor/011-persist-in-progress-match`
- Commit style: `feat(watch): persist in-progress match and offer resume`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Create `MatchPersistence` in Shared

Create `BeachTennisCounter/Shared/MatchPersistence.swift`:

```swift
import Foundation

/// Persists the in-progress match so a watchOS app termination mid-match
/// doesn't lose the score. UserDefaults-backed; one match at a time.
enum MatchPersistence {
    static let key = "inProgressMatch"
    /// A saved match older than this is considered abandoned, not resumable.
    static let defaultMaxAge: TimeInterval = 12 * 60 * 60

    private struct Saved: Codable {
        var state: MatchState
        var savedAt: Date
    }

    static func save(
        _ state: MatchState,
        in defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        guard !state.isMatchOver else {
            clear(in: defaults)
            return
        }
        guard let data = try? JSONEncoder().encode(Saved(state: state, savedAt: now)) else { return }
        defaults.set(data, forKey: key)
    }

    static func load(
        in defaults: UserDefaults = .standard,
        now: Date = Date(),
        maxAge: TimeInterval = defaultMaxAge
    ) -> MatchState? {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(Saved.self, from: data),
              !saved.state.isMatchOver,
              now.timeIntervalSince(saved.savedAt) <= maxAge
        else { return nil }
        return saved.state
    }

    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
```

Run `cd BeachTennisCounter && xcodegen generate`.

**Verify**: xcodegen exits 0; `grep -c "MatchPersistence.swift" BeachTennisCounter/BeachTennisCounter.xcodeproj/project.pbxproj` → ≥ 1.

### Step 2: Hook save/clear into `ScoreView`

All edits in `ScoreView.swift`:

1. **Init** — add an optional restored state (default keeps both existing call
   sites in `ServeSelectionView` source-compatible):

```swift
init(initialServer: Team, matchType: MatchType, restoredState: MatchState? = nil, isActive: Binding<Bool>) {
    self.initialServer = initialServer
    self.matchType = restoredState?.matchType ?? matchType
    self._isActive = isActive
    if let restored = restoredState {
        _state = State(initialValue: restored)
    } else {
        var s = MatchState()
        s.matchType = matchType
        s.servingTeam = initialServer
        s.initialServer = initialServer
        s.tiebreakFirstServer = initialServer
        s.matchStartDate = Date()
        _state = State(initialValue: s)
    }
}
```

2. **`awardPoint(to:)`** — persist after the engine mutates (clears itself at
   match end via the guard in `save`):

```swift
private func awardPoint(to team: Team) {
    history.append(state)
    ScoreEngine.awardPoint(to: team, state: &state)
    MatchPersistence.save(state)
    WKInterfaceDevice.current().play(.click)
}
```

3. **`undoLast()`** — add `MatchPersistence.save(state)` immediately after
   `state = previous`.

4. **Cancel path** — in the alert (lines 50-53), the destructive button
   becomes:

```swift
Button("End Match", role: .destructive) {
    MatchPersistence.clear()
    isActive = false
}
```

5. **New-match overwrite** — add to the view's modifier chain (next to the
   existing `.onChange`):

```swift
.onAppear {
    MatchPersistence.save(state)
}
```

This makes starting a fresh match immediately replace any stale saved match,
so Home's resume button can never resurrect a match the user already walked
away from. (Re-fires after the history sheet closes — harmless idempotent
overwrite. `save` refuses finished matches, so the match-over case is
covered.)

**Verify**: `grep -c "MatchPersistence" BeachTennisCounter/watchOS/Views/ScoreView.swift` → 4 (awardPoint, undoLast, cancel, onAppear).

### Step 3: Offer "Resume Match" in `HomeView`

All edits in `HomeView.swift`:

1. Add state next to the existing `@State` vars:

```swift
@State private var resumableMatch: MatchState? = nil
@State private var navigateToResume = false
```

2. Inside the `VStack(spacing: 12)`, directly below the `Text("New Match")`,
   add:

```swift
if resumableMatch != nil {
    Button {
        navigateToResume = true
    } label: {
        Label("Resume Match", systemImage: "arrow.uturn.forward.circle")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.orange)
    }
    .buttonStyle(.bordered)
    .tint(.orange)
}
```

(Style matches the repo's existing accents: orange highlights, `.bordered` +
`.tint(.orange)` as in `ScoreView`'s match-over "Done" button.)

3. Add a third `navigationDestination` after the existing two (lines 40-46):

```swift
.navigationDestination(isPresented: $navigateToResume) {
    if let match = resumableMatch {
        ScoreView(
            initialServer: match.servingTeam,
            matchType: match.matchType,
            restoredState: match,
            isActive: $navigateToResume
        )
    }
}
```

4. Refresh on every visit — add to the `ZStack`'s modifier chain (alongside
   `.navigationBarHidden(true)`):

```swift
.onAppear {
    resumableMatch = MatchPersistence.load()
}
```

Returning home after a finished/cancelled match re-runs `load()`, which
returns nil (cleared or finished), hiding the button.

**Verify**: `cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build` → `** BUILD SUCCEEDED **`.

### Step 4: Unit tests

Create `BeachTennisCounter/Tests/MatchPersistenceTests.swift` (structure
modeled on `PointScoreTests.swift`; isolated `UserDefaults` per test):

```swift
import XCTest
@testable import BeachTennisCounter

final class MatchPersistenceTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "MatchPersistenceTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func sampleState() -> MatchState {
        var s = MatchState()
        s.setScoreA = 3
        s.setScoreB = 2
        s.pointA = .thirty
        s.servingTeam = .b
        return s
    }

    func test_saveThenLoad_roundtripsState() {
        MatchPersistence.save(sampleState(), in: defaults)
        let loaded = MatchPersistence.load(in: defaults)
        XCTAssertEqual(loaded?.setScoreA, 3)
        XCTAssertEqual(loaded?.setScoreB, 2)
        XCTAssertEqual(loaded?.pointA, .thirty)
        XCTAssertEqual(loaded?.servingTeam, .b)
    }

    func test_load_returnsNilWhenNothingSaved() {
        XCTAssertNil(MatchPersistence.load(in: defaults))
    }

    func test_load_returnsNilWhenStale() {
        let savedAt = Date(timeIntervalSince1970: 1_000_000)
        MatchPersistence.save(sampleState(), in: defaults, now: savedAt)
        let later = savedAt.addingTimeInterval(MatchPersistence.defaultMaxAge + 1)
        XCTAssertNil(MatchPersistence.load(in: defaults, now: later))
    }

    func test_load_returnsStateJustInsideMaxAge() {
        let savedAt = Date(timeIntervalSince1970: 1_000_000)
        MatchPersistence.save(sampleState(), in: defaults, now: savedAt)
        let later = savedAt.addingTimeInterval(MatchPersistence.defaultMaxAge - 1)
        XCTAssertNotNil(MatchPersistence.load(in: defaults, now: later))
    }

    func test_save_finishedMatch_clearsInsteadOfSaving() {
        MatchPersistence.save(sampleState(), in: defaults)
        var finished = sampleState()
        finished.isMatchOver = true
        MatchPersistence.save(finished, in: defaults)
        XCTAssertNil(MatchPersistence.load(in: defaults))
    }

    func test_clear_removesSavedMatch() {
        MatchPersistence.save(sampleState(), in: defaults)
        MatchPersistence.clear(in: defaults)
        XCTAssertNil(MatchPersistence.load(in: defaults))
    }
}
```

Run `cd BeachTennisCounter && xcodegen generate` (new test file), then the
test gate.

**Verify**: `** TEST SUCCEEDED **`, including the 6 new `MatchPersistenceTests`.

## Test plan

Covered by Step 4: roundtrip, empty load, stale cutoff (both sides of the
boundary), finished-match clearing, explicit clear. The SwiftUI wiring
(Steps 2-3) has no seam in this test target — gates are the watch build plus
this manual QA note for the operator: score a few points, force-quit the watch
app (long-press side button → ⨉), relaunch → Home shows "Resume Match" and
tapping it restores the exact score with the correct server dot.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -c "MatchPersistence" BeachTennisCounter/watchOS/Views/ScoreView.swift` → 4
- [ ] `grep -c "MatchPersistence.load" BeachTennisCounter/watchOS/Views/HomeView.swift` → 1
- [ ] Watch build → `** BUILD SUCCEEDED **`
- [ ] Test command → `** TEST SUCCEEDED **`; `MatchPersistenceTests` (6 tests) pass
- [ ] `git status` shows changes only to in-scope files (plus regenerated `.xcodeproj`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `ScoreView`'s init or `awardPoint`/`undoLast` no longer match the excerpts
  (beyond plan 008's expected one-line sheet change).
- The test target cannot resolve `MatchPersistence` — check it was created
  under `Shared/`, not `watchOS/`; if it *is* in `Shared/` and still fails,
  report rather than editing `project.yml`.
- You are tempted to also persist the undo `history` array or to sync the
  in-progress state to the phone — both are explicit non-goals here.

## Maintenance notes

- Resume drops undo history (only the current state is saved). If that stings
  in practice, `Saved` can grow a `history: [MatchState]` field later — the
  JSON stays small (< ~100KB even for marathon matches).
- The 12-hour `defaultMaxAge` is a product guess; it lives in one constant.
- Plan 012 (pt-BR localization) includes a translation for the "Resume Match"
  label added here — if 012 lands first, the string simply shows in English
  until this plan lands; no coordination needed beyond serial landing with 008
  (shared file: `ScoreView.swift`).
- Reviewer should scrutinize: `MatchPersistence.clear()` on the cancel path
  and the `guard !state.isMatchOver` in `save` — together they guarantee a
  finished or cancelled match can never be offered for resume.
