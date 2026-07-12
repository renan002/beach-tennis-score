# Plan 008: Make history/detail views use the configured team colors

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5497f0b..HEAD -- BeachTennisCounter/iOS/Views/MatchDetailView.swift BeachTennisCounter/watchOS/Views/MatchHistoryView.swift BeachTennisCounter/watchOS/Views/ScoreView.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (soft: plan 001 for the test gate)
- **Category**: tech-debt
- **Planned at**: commit `5497f0b`, 2026-07-12
- **Issue**: https://github.com/renan002/beach-tennis-score/issues/8

## Why this matters

Settings let the user pick per-team colors from a 5-color palette
(`SettingsView.swift:3-9`), and the live watch scoreboard honors them
(`ScoreView` uses `sessionManager.teamAColor`/`teamBColor`). But the history
surfaces hardcode the two *default* hexes — a user who set Team A to green
still sees Team A as red in the match detail and in the mid-match history
sheet. Three call sites duplicate the literals `"E74C3C"`/`"5B8DEF"`, which is
exactly the divergence the settings palette was supposed to centralize.

## Current state

The three hardcoded sites:

- `BeachTennisCounter/watchOS/Views/MatchHistoryView.swift:25-27` (watch, shown
  mid-match via a sheet from `ScoreView`):

```swift
Text(record.winner == .a ? "A" : "B")
    .font(.caption2.bold())
    .foregroundColor(record.winner == .a ? Color(hex: "E74C3C") : Color(hex: "5B8DEF"))
```

- `BeachTennisCounter/iOS/Views/MatchDetailView.swift:94-98` (`SetRecordRow`,
  a `private struct` in that file):

```swift
Text(record.winner == .a ? "A" : "B")
    ...
    .background(Circle().fill(record.winner == .a ? Color(hex: "E74C3C") : Color(hex: "5B8DEF")))
```

- `BeachTennisCounter/iOS/Views/MatchDetailView.swift:133-137`
  (`GameRecordRow`, same file, same pattern inside the `else` branch).

Where the real colors live:

- Watch: `WatchSessionManager` (`@MainActor` singleton, injected as
  `@EnvironmentObject` everywhere — see `ScoreView.swift:5`) exposes
  `@Published var teamAColor: Color` / `teamBColor` (`WatchSessionManager.swift:9-10`).
- iOS: `PhoneSessionManager` exposes `@AppStorage("teamAColorHex")` /
  `teamBColorHex` as hex strings (`PhoneSessionManager.swift:10-11`); iOS has a
  **non-failable** `Color(hex:)` (`PhoneSessionManager.swift:116`). The watch
  `Color(hex:)` is **failable** (`WatchSessionManager.swift:79`) — on the watch,
  prefer the already-decoded `sessionManager.teamAColor`, not `Color(hex:)`.
- Presentation chain: `MatchHistoryView` is presented as a sheet from
  `ScoreView.swift:47-49`; `MatchDetailView` is pushed via `NavigationLink`
  from `MatchListView.swift:120`, which already has `phoneSession` as an
  `@EnvironmentObject`.
- Repo convention: both session managers are injected with
  `.environmentObject(...)` at the app root (`BeachTennisWatchApp.swift:10`,
  `BeachTennisApp.swift:39`) and consumed via
  `@EnvironmentObject private var ...` (see `ScoreView.swift:5`,
  `MatchListView.swift:5`). Match it.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Watch-only build (fast gate for watch files) | `cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build` | `** BUILD SUCCEEDED **` |
| Full test/build gate (compiles iOS files) | see "Verified commands" in `plans/README.md` (from plan 001) | `** TEST SUCCEEDED **` |
| Hardcoded-hex check | `grep -rn "E74C3C\|5B8DEF" BeachTennisCounter/iOS/Views/MatchDetailView.swift BeachTennisCounter/watchOS/Views/MatchHistoryView.swift` | no output |

## Scope

**In scope** (the only files you should modify):
- `BeachTennisCounter/watchOS/Views/MatchHistoryView.swift`
- `BeachTennisCounter/watchOS/Views/ScoreView.swift` (one line: pass the environment object into the sheet)
- `BeachTennisCounter/iOS/Views/MatchDetailView.swift`

**Out of scope** (do NOT touch):
- `SettingsView.swift:3-9` — the palette definition stays where it is (its
  hexes are the source of truth, not duplication).
- `PhoneSessionManager.swift` / `WatchSessionManager.swift` — no new API;
  everything needed is already published (plans 003/004/005 own those files).
- Persisting per-match colors in `StoredMatch` — bigger design change; history
  intentionally reflects the *current* color settings (see Maintenance notes).
- The default hexes in `PhoneSessionManager.swift:10-11` and the fallbacks in
  `WatchSessionManager.applyColors` — they are defaults, not display sites.

## Git workflow

- Branch: `advisor/008-history-views-use-configured-colors`
- Commit style: `fix(ui): history and detail views use configured team colors`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Watch — `MatchHistoryView` reads the session colors

In `MatchHistoryView.swift`:

1. Add to the struct, above `let history`:

```swift
@EnvironmentObject private var sessionManager: WatchSessionManager
```

2. Replace the `foregroundColor` at line 27 with:

```swift
.foregroundColor(record.winner == .a ? sessionManager.teamAColor : sessionManager.teamBColor)
```

In `ScoreView.swift`, make the environment explicit for the sheet (sheet
content on watchOS should not rely on implicit propagation), changing lines
47-49 to:

```swift
.sheet(isPresented: $showHistory) {
    MatchHistoryView(history: state.gameHistory)
        .environmentObject(sessionManager)
}
```

**Verify**: `cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build` → `** BUILD SUCCEEDED **`.

### Step 2: iOS — `MatchDetailView` rows read the settings hexes

In `MatchDetailView.swift`, in **both** `SetRecordRow` and `GameRecordRow`
(private structs at the bottom of the file):

1. Add to each struct, above `let record`:

```swift
@EnvironmentObject private var phoneSession: PhoneSessionManager
```

2. Replace each hardcoded fill:

```swift
.background(Circle().fill(record.winner == .a
    ? Color(hex: phoneSession.teamAColorHex)
    : Color(hex: phoneSession.teamBColorHex)))
```

(`Color(hex:)` here is the iOS non-failable initializer — no unwrapping.)

The rows are built inside `MatchDetailView`'s `List`, which inherits
`phoneSession` from `MatchListView`'s environment through the
`NavigationLink` push — no explicit injection needed on iOS.

**Verify**: `grep -rn "E74C3C\|5B8DEF" BeachTennisCounter/iOS/Views/MatchDetailView.swift BeachTennisCounter/watchOS/Views/MatchHistoryView.swift` → no output.

### Step 3: Compile/test gate

Run the verified test command (compiles the iOS target).

**Verify**: `** TEST SUCCEEDED **`.

## Test plan

No new unit tests — the change is SwiftUI color plumbing with no seam in the
current test target (no ViewInspector/UI-test infra in this repo). Gates: the
watch build (Step 1), the hex grep (Step 2), the test command (Step 3).
Manual QA note for the operator: set Team A to Green in Settings, open an old
match's detail → the "A" badges are green; on the watch, mid-match history
shows the configured colors.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -rn "E74C3C\|5B8DEF" BeachTennisCounter --include='*.swift' | grep -v SettingsView | grep -v PhoneSessionManager` → no output
- [ ] Watch build → `** BUILD SUCCEEDED **`
- [ ] Test command → `** TEST SUCCEEDED **`
- [ ] `git status` shows changes only to the 3 in-scope files
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The row structs in `MatchDetailView.swift` have been restructured (moved to
  their own files, made non-private) since `5497f0b`.
- The watch build fails on the failable/non-failable `Color(hex:)` split —
  it means shared code is seeing the wrong platform's initializer; do NOT
  "fix" that by editing the session managers.
- You are tempted to add colors to `StoredMatch`/`MatchResultPayload` — that
  is an explicit non-goal here.

## Maintenance notes

- History colors now reflect the *current* settings; changing colors recolors
  past matches. That is the accepted behavior of this plan. If per-match color
  fidelity is ever wanted, it needs fields on `StoredMatch` + payload keys —
  coordinate with plan 003's payload changes.
- Reviewer should scrutinize: `.environmentObject(sessionManager)` on the
  sheet (Step 1) — removing it may still compile but can crash at runtime on
  watchOS if implicit propagation isn't there.
