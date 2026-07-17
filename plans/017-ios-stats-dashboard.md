# Plan 017: Add a Match History summary/stats view to the iOS app

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan in
> `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9d05103..HEAD -- BeachTennisCounter/iOS/Views/MatchListView.swift BeachTennisCounter/iOS/Models/StoredMatch.swift`
> If either changed since this plan was written, compare the "Current state"
> excerpts against the live code before proceeding; on a mismatch, treat it as a
> STOP condition.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: LOW (pure-additive iOS read-only view; no schema, no protocol, no watch change)
- **Depends on**: none (soft: the test/build gate below). Gains per-player depth *after* plan 015 (named teams) lands, but is valuable anonymously now.
- **Category**: direction
- **Planned at**: commit `9d05103`, 2026-07-17

## Why this matters

The iOS app stores every completed match but never summarizes anything. Match
History is a flat reverse-chronological list (`MatchListView`) with a
sport filter and per-row detail — there is no win/loss record, no totals, no
"matches this month", no average duration, no longest match. All the data to
compute these is already persisted in `StoredMatch` and already queried. A
lightweight, read-only stats view turns a pile of rows into something a player
actually returns to the app to see, at essentially zero risk: it adds a view
and reads existing data, touching no model, no sync protocol, and no watch code.

## Current state

- **Everything needed is already queried.** `iOS/Views/MatchListView.swift:7`:

```swift
@Query(sort: \StoredMatch.date, order: .reverse) private var allMatches: [StoredMatch]
```

- **The fields available per match** (`iOS/Models/StoredMatch.swift`):
  - `date: Date` (line 6), `duration: TimeInterval` (line 17)
  - `winner: String` (line 16) — `"a"` or `"b"`; `winnerTeam: Team?` (line 70)
  - `matchType: MatchType` (line 67) / `matchTypeRaw: String` (line 20)
  - `scoreDisplay: String` (lines 72-77), `durationDisplay: String` (lines 79-83)
- **The list is presented in a `NavigationStack` with a toolbar** — the stats
  entry point goes here. `MatchListView.swift:38-50`:

```swift
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
```

- **Repo conventions to match**:
  - Views are structs with small `private var`/`private func` members at the
    bottom (see `MatchListView`'s `filterPicker`, `emptyState`, `matchList`).
  - UI strings localize via `Text("…")`/`LocalizedStringKey`; computed
    `String`s use `String(localized: "…")` (see `MatchListView.filterLabel`,
    lines 121-127). CLAUDE.md: any new UI copy is added to
    `Shared/Localizable.xcstrings` (the single strings table). **Universal
    tennis/number vocabulary is intentionally left unkeyed** — but full English
    sentences like "Matches this month" need catalog entries for pt-BR.
  - Sport labels: beach = orange, tennis = green (see `MatchRowView.sportBadge`,
    lines 208-219). Reuse that convention if you break stats out by sport.
  - CONTEXT.md term: the durable collection is **"Match History"** — use it in
    the view title/copy; avoid "history"/"backup" as user-facing words.

- **No stats/aggregation code exists** anywhere to extend — this is greenfield
  within the iOS target. `grep -rn "reduce\|filter { .*winner" BeachTennisCounter/iOS` returns only the sport filter.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Regenerate project after adding a `.swift` file | `cd BeachTennisCounter && xcodegen generate` | `Created project at …` |
| Full build/test gate (compiles iOS files) | `cd BeachTennisCounter && xcodebuild test -project BeachTennisCounter.xcodeproj -scheme BeachTennisCounter -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Unit tests only (pure logic) | same as above | `** TEST SUCCEEDED **` |

If `iPhone 17` is unavailable, pick any device from
`xcrun simctl list devices available` and substitute it.

## Suggested executor toolkit

- After creating any new `.swift` file you MUST run `xcodegen generate` before
  building — the `.xcodeproj` will not pick it up otherwise (CLAUDE.md).

## Scope

**In scope**:
- `BeachTennisCounter/iOS/Models/MatchStats.swift` (create) — a pure,
  `struct`-based aggregator over `[StoredMatch]`, **unit-testable in isolation**.
- `BeachTennisCounter/iOS/Views/MatchStatsView.swift` (create) — the SwiftUI
  view rendering the aggregate.
- `BeachTennisCounter/iOS/Views/MatchListView.swift` — add ONE toolbar entry
  point (a chart/stats button) that presents `MatchStatsView`.
- `BeachTennisCounter/Shared/Localizable.xcstrings` — add pt-BR entries for any
  new full-sentence UI copy.
- `BeachTennisCounter/Tests/MatchStatsTests.swift` (create) — tests for the
  aggregator.

**Out of scope** (do NOT touch):
- `StoredMatch.swift` — no new persisted fields; stats are computed, not stored.
- Any watch file, `WatchMessage.swift`, `PhoneSessionManager.swift` — no
  protocol or sync change.
- Per-player / per-name stats — teams are still anonymous (`Team A`/`Team B`)
  until plan 015 lands. Design the aggregator so a `groupBy` player dimension can
  be *added later* without rewrite, but do **not** build it now.
- Charts framework eye-candy is optional; if you use Swift `Charts`, keep it to
  one simple bar/summary — do not let it balloon the plan.

## Git workflow

- Branch: `advisor/017-ios-stats-dashboard`
- Commit style: `feat(ios): add a Match History summary view`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Build the pure aggregator (testable, no SwiftUI)

Create `BeachTennisCounter/iOS/Models/MatchStats.swift`. It must be a plain
value type computed from `[StoredMatch]`, importing only `Foundation` — **no
SwiftUI, no SwiftData query** — so it is unit-testable without a running app:

```swift
import Foundation

struct MatchStats {
    let totalMatches: Int
    let winsA: Int
    let winsB: Int
    let matchesThisMonth: Int
    let averageDuration: TimeInterval   // 0 when totalMatches == 0
    let longestDuration: TimeInterval   // 0 when totalMatches == 0
    let beachCount: Int
    let tennisCount: Int

    init(matches: [StoredMatch], now: Date = Date(), calendar: Calendar = .current) {
        // derive every field with reduce/filter over `matches`;
        // guard the empty case so averageDuration is 0, not NaN.
    }
}
```

Requirements:
- `averageDuration` must be `0` (not a divide-by-zero/NaN) when `matches` is
  empty — this is the key edge case the tests pin.
- `matchesThisMonth` uses the injected `calendar`/`now` (so tests are
  deterministic — do not read `Date()` internally except via the default arg).
- `winsA`/`winsB` count `match.winner == "a"` / `"b"`.

**Verify**: `grep -n "struct MatchStats" BeachTennisCounter/iOS/Models/MatchStats.swift` → 1 match.

### Step 2: Write the aggregator tests first-class

Create `BeachTennisCounter/Tests/MatchStatsTests.swift`, modeled structurally on
an existing pure-logic test — `Tests/MatchResultPayloadTests.swift` (round-trip
value tests) or `Tests/ScoreEngineTests.swift`. Cover:
- empty input → all zeros, `averageDuration == 0` (no NaN).
- one match → totals reflect it.
- mixed winners → `winsA`/`winsB` correct.
- mixed sports → `beachCount`/`tennisCount` correct.
- `matchesThisMonth` with an injected `now` and matches straddling the month
  boundary → only in-month counted.

You will need to construct `StoredMatch` instances in the test — its `init`
(`StoredMatch.swift:22-46`) takes all fields with defaults; pass `date`,
`winner`, `duration`, `matchTypeRaw` explicitly.

**Verify**: run the test command → `** TEST SUCCEEDED **` with the new
`MatchStatsTests` cases passing (after Step 5's `xcodegen generate`).

### Step 3: Build the stats view

Create `BeachTennisCounter/iOS/Views/MatchStatsView.swift`. A `NavigationStack`
+ `Form`/`List` of summary rows (mirror `MatchDetailView`'s sectioned `List`
style, `MatchDetailView.swift:6-69`). It takes the matches in and builds
`MatchStats`:

```swift
struct MatchStatsView: View {
    let matches: [StoredMatch]
    private var stats: MatchStats { MatchStats(matches: matches) }
    // sections: Overview (total, W-A/W-B, this month),
    //           Duration (average, longest), By Sport (beach/tennis counts)
}
```

Copy guidance: use `String(localized:)` for interpolated stat labels; keep
number/score glyphs unkeyed. Title the screen with the CONTEXT.md term (e.g.
`"Match History"` or `"Summary"`), not "History"/"Backup". Empty state: when
`matches.isEmpty`, show a short "No matches yet" message (reuse the phrasing
already in `MatchListView.emptyState`, line 154).

**Verify**: `grep -n "struct MatchStatsView" BeachTennisCounter/iOS/Views/MatchStatsView.swift` → 1 match.

### Step 4: Wire the entry point in MatchListView

Add a single toolbar button (e.g. `Image(systemName: "chart.bar")`) to the
existing `.toolbar` (`MatchListView.swift:39-50`) that presents `MatchStatsView`
via a `.sheet` (mirror the existing `showSettings` sheet pattern at lines
51-54). Pass `allMatches` (the full unfiltered set) so stats are over the whole
Match History, not the active filter. Add the `@State private var showStats = false`
alongside the existing `@State` vars (lines 8-10).

Do **not** disturb `filterPicker`, the settings button, or the quarantine
notices.

**Verify**: `grep -n "MatchStatsView\|showStats" BeachTennisCounter/iOS/Views/MatchListView.swift` → the sheet + state + presenting button.

### Step 5: Regenerate the project and run the full gate

```
cd BeachTennisCounter && xcodegen generate
```

Then run the build/test command from "Commands you will need".

**Verify**: `xcodegen generate` prints `Created project at …`; the test command
prints `** TEST SUCCEEDED **`.

### Step 6: Add pt-BR catalog entries

For each new full-sentence/label English string you introduced, add its pt-BR
translation in `Shared/Localizable.xcstrings`. Do **not** add entries for bare
tennis/number vocabulary (per CLAUDE.md — a missing entry renders the key,
which is correct for those). Re-run the test command to confirm the catalog
still compiles.

**Verify**: test command → `** TEST SUCCEEDED **`; and every new sentence key
has a pt-BR value (spot-check the catalog for your new keys).

## Test plan

- New file `Tests/MatchStatsTests.swift` with the cases in Step 2 (empty,
  single, mixed winners, mixed sports, month boundary). Model after
  `Tests/MatchResultPayloadTests.swift`.
- The view itself has no unit test (no UI-test infra in this repo — same
  rationale as plan 010); its gate is the compile in Step 5.
- Verification: test command → `** TEST SUCCEEDED **`, new `MatchStats` cases
  included.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `MatchStats.swift`, `MatchStatsView.swift`, `MatchStatsTests.swift` exist.
- [ ] `grep -n "import SwiftUI\|import SwiftData" BeachTennisCounter/iOS/Models/MatchStats.swift` → **no matches** (aggregator is pure Foundation).
- [ ] Test command → `** TEST SUCCEEDED **`, including new `MatchStatsTests`.
- [ ] `git status` shows changes only to: the three new files, `MatchListView.swift`, `Localizable.xcstrings`, and `BeachTennisCounter.xcodeproj` (from xcodegen).
- [ ] `git diff --name-only 9d05103..HEAD -- BeachTennisCounter/iOS/Models/StoredMatch.swift` → empty (no schema change).
- [ ] `plans/README.md` status row for 017 updated.

## STOP conditions

Stop and report back (do not improvise) if:

- `MatchListView`'s `@Query`/toolbar no longer matches the "Current state"
  excerpts (drift).
- You find yourself needing to add a field to `StoredMatch` to compute a stat —
  every stat in this plan is derivable from existing fields; if you want one
  that isn't, that is out of scope.
- The test command fails twice after a reasonable fix, or the only available
  simulator can't run it — report the exact xcodebuild error.
- You are tempted to add per-player grouping — names don't exist yet (plan 015);
  keep the anonymous `A`/`B` dimension only.

## Maintenance notes

- Once plan 015 (named teams) lands, `MatchStats` gains a natural per-name /
  head-to-head dimension — design the initializer so adding a grouping key is
  additive, not a rewrite. Note this in a code comment.
- Reviewer should scrutinize: the empty-input path (no NaN in `averageDuration`)
  and that the view is passed the *unfiltered* `allMatches`.
- Deferred out of scope: Swift `Charts` visualizations beyond one simple
  summary, streaks, and any per-player breakdown (blocked on 015).
