# Plan 015: Design named teams (spike — decide the UX + migration, do NOT ship the feature)

> **Executor instructions**: This is a **design spike**, not a build task. Your
> deliverable is a written design document plus a recommendation — you will
> **not** modify any Swift source, `project.yml`, or the String Catalog. Follow
> the steps, answer every open question with evidence from the codebase, and
> write the design file named in "Done criteria". If a STOP condition occurs,
> stop and report. When done, update this plan's row in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 9d05103..HEAD -- BeachTennisCounter/Shared/MatchState.swift BeachTennisCounter/Shared/WatchMessage.swift BeachTennisCounter/iOS/Models/StoredMatch.swift`
> If any of these changed since this plan was written, compare the "Current
> state" excerpts against the live code before proceeding; on a mismatch, note
> it in the design doc (it is not a blocker for a design-only spike, but the
> excerpts you cite must reflect reality).

## Status

- **Priority**: P2
- **Effort**: M (spike itself is S–M; the build it designs is M)
- **Risk**: LOW (design-only; ships nothing)
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `9d05103`, 2026-07-17

## Why this matters

Every match in the app is anonymous: teams are hardcoded `Team A` / `Team B`
(`MatchState.swift:3-12`, and the literal strings `"Team A"`/`"Team B"` in the
String Catalog). History is therefore a wall of `A 6–3 B` rows that a player
cannot connect to who actually played. Named teams turn Match History into a
real record and are the **enabling prerequisite** for per-player stats
(plan 017) and a meaningful share card (plan 018). But naming touches the
watch→phone protocol *and* the persisted SwiftData schema — and this repo has
already been burned once by a careless schema change (issue #47: a lightweight
migration failed because new non-optional attributes lacked property-level
defaults). So the right first move is a spike that pins down the UX and the
migration strategy **before** any code is written, not a blind implementation.

## Current state

The facts the spike must build on, inlined:

- **The label is anonymous at the model root.** `MatchState.swift:3-12`:

```swift
enum Team: String, Codable, Sendable {
    case a, b
    var other: Team { self == .a ? .b : .a }
    var displayName: String {
        self == .a
            ? NSLocalizedString("Team A", comment: "")
            : NSLocalizedString("Team B", comment: "")
    }
}
```

  `Team` is an identity enum used pervasively (serving team, winner, per-game
  winner). **Names must not be modeled as new `Team` cases** — the two-sided
  A/B identity is load-bearing across `ScoreEngine`. Names are *labels attached
  to* the A/B sides, carried alongside the match, not a replacement for `Team`.

- **The persisted record.** `iOS/Models/StoredMatch.swift:4-46` is the SwiftData
  `@Model`. Note the migration lesson already encoded there (lines 10-13):

```swift
// Property-level defaults (not just init defaults): SwiftData lightweight
// migration only accepts an added non-optional attribute when it is
// declared with a default here. Without these, a 1.1.x store fails to
// migrate (CocoaError 134110). See #47.
var setsWonA: Int = 0
var setsWonB: Int = 0
```

  Any new `StoredMatch` field the design proposes (e.g. `teamAName: String = ""`,
  `teamBName: String = ""`) **must** carry a property-level default for the same
  reason. `StoredMatch(copying:)` at lines 51-65 must also copy any new field
  (a restored Quarantined Store round-trips through it — see CONTEXT.md
  "Restore").

- **The wire protocol.** `Shared/WatchMessage.swift` — `MatchResultPayload`
  (lines 26-105) is the single encode/decode point for watch→phone. New match
  data is added in exactly three places: a `WatchMessageKey` constant (lines
  3-19), a field + `toDictionary()` entry (lines 39-59), and a `from(_:)` decode
  (lines 61-104). The decode already models "old sender, new receiver"
  tolerance with `?? default` fallbacks (e.g. line 74:
  `dict[WatchMessageKey.setsWonA] as? Int ?? 0`). A names field must decode the
  same way so a watch that predates names still delivers results.

- **Where a name would be entered on the watch.** The pre-match flow is
  `HomeView` → `ServeSelectionView` (`watchOS/Views/ServeSelectionView.swift`,
  55 lines) → `ScoreView`. `ServeSelectionView` is the natural entry point, but
  watch text entry (scribble/dictation) is slow — the UX question is real.
- **Where a name would be defaulted.** `iOS/Views/SettingsView.swift` already
  hosts Team A/Team B color pickers (lines 38-41) and syncs watch-consumed
  settings via `WatchSettings` (`Shared/WatchSettings.swift`). Default names, if
  any, would live here and ride the same `WatchSettings` sync path.
- **Vocabulary constraint (CONTEXT.md).** The domain glossary fixes "Match",
  "Match History", "Game", "Set". There is currently **no** term for a team's
  name. The design doc must propose the term (e.g. "Team Name") so it can be
  added to CONTEXT.md when the feature is built, and must not overload an
  existing `_Avoid_`-listed word.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Drift check | `git diff --stat 9d05103..HEAD -- BeachTennisCounter/Shared/MatchState.swift BeachTennisCounter/Shared/WatchMessage.swift BeachTennisCounter/iOS/Models/StoredMatch.swift` | empty (no drift) |
| Confirm no source changed | `git status --porcelain BeachTennisCounter/` | empty at the end of the spike |

This spike runs **no build and no tests** — it writes no code.

## Scope

**In scope** (the only file you create):
- `plans/015-player-team-names-design.md` — the design deliverable.

**Out of scope** (do NOT modify — this is a spike):
- Every `.swift` file, `project.yml`, `Shared/Localizable.xcstrings`,
  `CONTEXT.md`. The spike *recommends* changes to these; a later build plan makes
  them. If you find yourself editing code, STOP.

## Git workflow

- Branch: `advisor/015-player-team-names-spike`
- Commit style: `docs(spike): design named teams (UX + migration)`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Answer the model & migration questions in writing

In `plans/015-player-team-names-design.md`, decide and justify:

1. **Data shape.** Recommend carrying names as two optional/empty-defaulted
   strings attached to the A/B sides (not new `Team` cases). Specify the exact
   new fields for: `MatchState` (in-progress, on the watch), `MatchResultPayload`
   (wire), and `StoredMatch` (persisted). State the property-level default for
   the `StoredMatch` fields and confirm `StoredMatch(copying:)` must copy them.
2. **Migration safety.** Confirm the added `StoredMatch` fields follow the #47
   rule (property-level default on a non-optional attribute) and state what an
   existing 1.2.x store does on first launch after the change (empty names, no
   migration failure). This is the highest-risk part — be explicit.
3. **Backward/forward compatibility on the wire.** State how
   `MatchResultPayload.from(_:)` decodes a result from a watch that predates
   names (fallback to empty), mirroring the `setsWonA` pattern at line 74.

**Verify**: the design file contains a section answering all three, each citing
the specific `file:line` it affects.

### Step 2: Decide the entry-and-default UX

In the same file, choose and justify **one** primary approach, and note the
rejected alternatives with one line each:

- Option A — default names in iOS Settings only (rides existing `WatchSettings`
  sync; zero watch text entry; names are the same every match).
- Option B — per-match names entered on the watch in `ServeSelectionView`
  (flexible but slow scribble/dictation entry).
- Option C — hybrid: Settings provides defaults, the watch pre-match screen
  lets the player accept or override them.

Recommend one (a hybrid defaulting from Settings is the likely winner for a
watch-first app, but justify from the actual flow, not this hint). Sketch the
screen changes in prose + a text mock — do not write SwiftUI.

**Verify**: the file names exactly one recommended option and lists the
`file:line` of each view that would change.

### Step 3: Specify the display & localization impact

List every place `Team A`/`Team B` is shown and would instead show a name when
one exists, falling back to the localized "Team A"/"Team B" when empty:
- `MatchListView.swift` (`MatchRowView.winnerBadge`, ~line 221-228; the
  `A 6–3 B` score line ~197)
- `MatchDetailView.swift` (Winner row ~28; the per-set/per-game A/B badges)
- `Team.displayName` (`MatchState.swift:7-11`) — decide whether it stays the
  empty-name fallback.

State the localization rule: names are user data and are **never** translated
(consistent with CLAUDE.md "Never translate … UserDefaults-persisted strings").
The literal `"Team A"`/`"Team B"` catalog entries remain the fallback.

**Verify**: the file lists each display site as `file:line` with the fallback
behavior.

### Step 4: Write the recommendation & effort estimate

Close the design file with: a go/no-go recommendation, a 3–5 step outline of the
**build** plan this spike would spawn (the executor of that plan follows plans
006/010's concrete style), a coarse effort estimate (S/M/L) per surface (watch,
wire, iOS persistence, iOS display), and the ordered dependency (names must land
before plan 017 gains per-player value and before plan 018's card shows names).

**Verify**: `git status --porcelain BeachTennisCounter/` is empty (no source
touched) and `plans/015-player-team-names-design.md` exists.

## Test plan

None — a spike ships no code. The deliverable is the design document. Its
"tests" are the review questions in Done criteria: a reader must be able to
green-light a build plan from it without re-deriving the migration risk.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `plans/015-player-team-names-design.md` exists and contains four sections
      matching Steps 1–4.
- [ ] The migration section explicitly states the property-level-default rule
      (references #47 / `StoredMatch.swift:10-13`) and what happens to an
      existing store.
- [ ] Exactly one UX option is recommended, with the rejected ones noted.
- [ ] `git status --porcelain BeachTennisCounter/` is empty (no source, no
      `project.yml`, no catalog changes).
- [ ] `plans/README.md` status row for 015 updated.

## STOP conditions

Stop and report back (do not improvise) if:

- You conclude names cannot be added without breaking the SwiftData migration
  from an existing store (i.e. the #47 default trick is insufficient) — this
  changes the whole calculus and the maintainer must weigh in.
- The `Team` enum or `MatchResultPayload` has been refactored since this plan
  (drift check failed) such that the "add a field in three places" shape no
  longer holds.
- You find yourself writing Swift, editing `project.yml`, or adding catalog
  keys — that is the *build* plan's job, not this spike's.

## Maintenance notes

- The build plan this spawns must update CONTEXT.md with the new "Team Name"
  term and re-key the String Catalog only if UI copy changes (per CLAUDE.md's
  re-key-in-the-same-commit rule).
- Reviewer of the eventual build PR should scrutinize: the `StoredMatch`
  migration on a real 1.2.x store, and that `StoredMatch(copying:)` copies the
  new fields (Quarantined Store restore path).
- This spike deliberately excludes: avatars/photos, more than two teams, and
  doubles (4 individual player names) — note those as explicit non-goals in the
  design doc so the build plan stays bounded.
