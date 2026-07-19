# Plan 018: Share a match result from the iOS detail screen

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan in
> `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9d05103..HEAD -- BeachTennisCounter/iOS/Views/MatchDetailView.swift BeachTennisCounter/iOS/Models/StoredMatch.swift`
> If either changed since this plan was written, compare the "Current state"
> excerpts against the live code before proceeding; on a mismatch, treat it as a
> STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW (adds a share affordance over existing computed data; no model/protocol/watch change)
- **Depends on**: none (soft: the build gate). Better once plan 015 (named teams) lands — the card can show names instead of "Team A/B".
- **Category**: direction
- **Planned at**: commit `9d05103`, 2026-07-17

## Two-line summary for the reviewer

Add a `ShareLink` to `MatchDetailView` that shares a one-line text summary of
the finished match ("Beach Tennis · A 6–3 B · Team A wins · 42:15 · Jul 17").
The app has **no sharing anywhere today**, and its audience is pt-BR /
WhatsApp-heavy where sharing a result is the natural social loop.

## Why this matters

Beach tennis is a social, communal sport, and this app is fully localized to
Brazilian Portuguese — an audience for whom sharing a result to WhatsApp is the
expected end-of-match gesture. Yet the app has **zero** share surface:
`grep -rn "ShareLink\|UIActivity" BeachTennisCounter` returns nothing. Adding a
share action to the match detail screen is a small, self-contained, additive
change that meaningfully increases the app's day-to-day usefulness and word of
mouth, using only data the screen already displays.

## Current state

- **The detail screen already renders everything the share text needs.**
  `iOS/Views/MatchDetailView.swift:6-69` shows sport, score, winner, date, and
  duration. The `StoredMatch` accessors it uses (`iOS/Models/StoredMatch.swift`):
  - `match.matchType.displayName` (`MatchType.displayName`, localized)
  - `match.scoreDisplay` (`StoredMatch.swift:72-77`) — e.g. `"6 – 3"`
  - `match.winner` (`"a"`/`"b"`) — the view formats it as
    `"Team \(match.winner.uppercased())"` (`MatchDetailView.swift:28`)
  - `match.durationDisplay` (`StoredMatch.swift:79-83`) — `"m:ss"`
  - `match.date` (formatted at `MatchDetailView.swift:39`)
- **The screen is a `List` with a `.navigationTitle` and inline title mode**,
  no toolbar yet (`MatchDetailView.swift:67-68`):

```swift
.navigationTitle("Match Details")
.navigationBarTitleDisplayMode(.inline)
```

  A `.toolbar { ToolbarItem(placement: .topBarTrailing) { ShareLink(...) } }`
  is the natural home for the share button.
- **Localization convention (CLAUDE.md)**: `Text("…")` localizes automatically;
  a computed `String` (which the share text is) must use `String(localized:)`
  with interpolation. New full-sentence copy gets a pt-BR entry in
  `Shared/Localizable.xcstrings`. Score/number glyphs stay unkeyed.
- **Team names do not exist yet** — the share text uses the same
  `"Team A"/"Team B"` the rest of the UI uses. When plan 015 lands, the card
  swaps in real names; keep the winner-label derivation in one small helper so
  that later swap is a one-line change.
- CONTEXT.md: a match is a "Match"; do not call the shared artifact a "backup"
  or "history".

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Full build/test gate | `cd BeachTennisCounter && xcodebuild test -project BeachTennisCounter.xcodeproj -scheme BeachTennisCounter -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |

Substitute an available device from `xcrun simctl list devices available` if
`iPhone 17` is absent. No `xcodegen generate` is needed **if you add no new
`.swift` file** (this plan edits one existing file). If you choose to extract a
helper into a new file, you MUST run `xcodegen generate` first.

## Scope

**In scope**:
- `BeachTennisCounter/iOS/Views/MatchDetailView.swift` — add the `ShareLink`
  toolbar item and a small `shareText` computed helper.
- `BeachTennisCounter/Shared/Localizable.xcstrings` — pt-BR entry for the share
  string template if it contains full-sentence copy (e.g. a "… wins" clause).

**Out of scope** (do NOT touch):
- `StoredMatch.swift`, `WatchMessage.swift`, any watch file, session managers —
  no data, protocol, or sync change.
- A rendered **image** share card. v1 is **text only** (a text share works in
  every target app including WhatsApp with zero layout/design work). A
  `ShareLink` over an `Image` rendered via `ImageRenderer` is a fine follow-up —
  do not build it here; it needs design and doubles the surface.
- Sharing from the list row or from Settings — detail screen only.
- Any analytics/tracking of shares.

## Git workflow

- Branch: `advisor/018-share-match-result`
- Commit style: `feat(ios): share a match result from the detail screen`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add the share-text helper

In `MatchDetailView` add a computed `private var shareText: String` that builds
a single localized line from the existing accessors. Keep the winner label in a
tiny sub-expression so plan 015 can later swap in a name:

```swift
private var shareText: String {
    let winnerLabel = String(localized: "Team \(match.winner.uppercased())")
    return String(
        localized: "\(match.matchType.displayName) · A \(match.scoreDisplay) B · \(winnerLabel) wins · \(match.durationDisplay)"
    )
}
```

(Exact separator/wording is yours — keep it one line, human-readable, and put
any full-sentence fragment through `String(localized:)`. Do not invent data the
match doesn't have.)

**Verify**: `grep -n "shareText" BeachTennisCounter/iOS/Views/MatchDetailView.swift` → the computed var + its use in Step 2.

### Step 2: Add the ShareLink to the toolbar

Attach a toolbar to the `List` (alongside the existing `.navigationTitle` /
`.navigationBarTitleDisplayMode` at lines 67-68):

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        ShareLink(item: shareText) {
            Image(systemName: "square.and.arrow.up")
        }
    }
}
```

**Verify**: `grep -n "ShareLink" BeachTennisCounter/iOS/Views/MatchDetailView.swift` → 1 match.

### Step 3: Build/test gate

Run the build/test command from "Commands you will need".

**Verify**: `** TEST SUCCEEDED **`.

### Step 4: Localize the share string

Add the pt-BR translation for the new share-string template (and the
`"Team %@"`/`"… wins"` fragment if newly introduced) to
`Shared/Localizable.xcstrings`. Re-run the build/test command.

**Verify**: `** TEST SUCCEEDED **`, and the new key(s) have a pt-BR value.

## Test plan

No new unit test: the change is a computed string + a SwiftUI `ShareLink` with
no seam in the current test target (consistent with plan 010's rationale — no
UI-test infra in this repo). Gates: Step 1–2 greps and the Step 3 compile.
Manual QA note for the operator: open a finished match → tap share → the share
sheet shows the one-line summary; sending to Notes/WhatsApp pastes it intact.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -c "ShareLink" BeachTennisCounter/iOS/Views/MatchDetailView.swift` → 1
- [ ] Build/test command → `** TEST SUCCEEDED **`
- [ ] `git status` shows changes only to `MatchDetailView.swift` and
      `Localizable.xcstrings` (and `.xcodeproj` only if you added a new file and
      ran `xcodegen`).
- [ ] `git diff --name-only 9d05103..HEAD -- BeachTennisCounter/iOS/Models/StoredMatch.swift` → empty.
- [ ] `plans/README.md` status row for 018 updated.

## STOP conditions

Stop and report back (do not improvise) if:

- `MatchDetailView`'s accessors (`scoreDisplay`, `durationDisplay`, `winner`) no
  longer match the "Current state" excerpts (drift).
- You find yourself building an `ImageRenderer` share card, or adding a share
  button anywhere but the detail screen — that is out of scope.
- The build fails twice after a reasonable fix — report the exact error.

## Maintenance notes

- When plan 015 (named teams) lands, `shareText`'s `winnerLabel` and the
  `A … B` sides should show real names — that is why the winner label is
  isolated in one sub-expression.
- Follow-up explicitly deferred: a rendered image scorecard
  (`ShareLink` over an `ImageRenderer` view) — higher polish, needs design.
- Reviewer should scrutinize: the share string is fully localized (no bare
  English `String` literal escaping `String(localized:)`).
