# Design 015: Named teams — UX + migration (spike deliverable)

> Deliverable of [plan 015](015-player-team-names-spike.md) (design spike, ships
> no code). Decisions were resolved on the wayfinder map
> [#62](https://github.com/renan002/beach-tennis-score/issues/62) — migration
> ([#67](https://github.com/renan002/beach-tennis-score/issues/67)), entry UX
> ([#68](https://github.com/renan002/beach-tennis-score/issues/68)), display &
> localization ([#69](https://github.com/renan002/beach-tennis-score/issues/69)).
> Drift check (`git diff --stat 9d05103..HEAD` over `MatchState.swift`,
> `WatchMessage.swift`, `StoredMatch.swift`) was empty at design time — every
> `file:line` below cites the live code.

## 1. Data model & migration

### Data shape

Names are **labels attached to the A/B sides**, carried alongside the match.
`Team` (`Shared/MatchState.swift:3-12`) gains **no new cases** — its two-sided
identity is load-bearing across `ScoreEngine`.

Two **non-optional `String` fields with `""` meaning "unnamed"** — never
`Optional<String>`. This matches the model's existing convention for
later-added fields (`gameHistoryData: Data = Data()`,
`matchTypeRaw: String = "beachTennis"` at `StoredMatch.swift:18-20`), avoids
nil-vs-empty ambiguity at display sites, and is #47-safe.

| Surface | Fields | Notes |
|---|---|---|
| `MatchState` (`Shared/MatchState.swift:88`) | `var teamAName: String = ""` / `var teamBName: String = ""` | Defaults keep every existing initializer and the `ScoreView` undo-stack copies working unchanged. Add `func teamName(for team: Team) -> String` mirroring the `setScore(for:)` accessor family (`MatchState.swift:126-140`) — see §3 resolver. |
| `MatchResultPayload` (`Shared/WatchMessage.swift:26-105`) | same two fields, in the established three places | 1) `WatchMessageKey.teamAName`/`.teamBName` constants (`WatchMessage.swift:3-19`); 2) `let` fields + `toDictionary()` entries (`:39-59`); 3) `from(_:)` decode with `?? ""` (see wire compatibility). |
| `StoredMatch` (`iOS/Models/StoredMatch.swift`) | `var teamAName: String = ""` / `var teamBName: String = ""` — **property-level** defaults | Plus defaulted init parameters, **and both fields copied in `StoredMatch(copying:)`** (`StoredMatch.swift:51-65`) — its doc comment mandates that a Quarantined-Store restore round-trips whole. `PhoneSessionManager.insertMatch` (`PhoneSessionManager.swift:86-98`) passes `payload.teamAName`/`payload.teamBName` through. |

### Migration safety (the highest-risk part — explicit)

Per the #47 lesson encoded at `StoredMatch.swift:10-13`: SwiftData lightweight
migration accepts an added **non-optional** attribute only when the default is
declared **at the property level** — an init-parameter default is not enough
(that is exactly what produced CocoaError 134110 in #47). With
`var teamAName: String = ""` declared as above:

- **Existing 1.2.x store, first launch after update:** the store migrates in
  place; every existing `StoredMatch` row materializes with empty names. No
  migration failure, no data loss, no user-visible change (empty names fall
  back to the localized "Team A"/"Team B" per §3).
- **Quarantined Store restore:** round-trips through `StoredMatch(copying:)`,
  which copies the new fields — restored matches keep their names.

The spike's STOP condition ("#47 default trick insufficient") did **not**
trigger: the trick suffices.

### Wire backward/forward compatibility

`MatchResultPayload.from(_:)` (`WatchMessage.swift:61-104`) already splits
fields into two tiers: v1 fields are `guard`-required (`:62-70`); every later
addition decodes with a `?? default` fallback (`setsWonA`/`setsWonB` at
`:74-75`, `matchType` at `:77`). Names join the second tier:

```swift
let teamAName = dict[WatchMessageKey.teamAName] as? String ?? ""
let teamBName = dict[WatchMessageKey.teamBName] as? String ?? ""
```

- **Old watch → new phone:** keys absent → names decode to `""` → the result
  is stored and displayed with the anonymous fallback. Results are never
  dropped.
- **New watch → old phone:** the old `from(_:)` ignores unknown dictionary
  keys → the result stores fine; names are silently discarded. Acceptable.

## 2. Entry-and-default UX

**Recommended: Option A — default names in iOS Settings only.** Chosen with
the maintainer over text mocks (#68).

Rejected:

- **Option B (per-match watch entry):** inserts slow scribble/dictation before
  every match, taxing the two-tap fast path `HomeView → ServeSelectionView →
  ScoreView`.
- **Option C (hybrid):** keeps the fast path but adds a watch edit screen and
  per-match override state judged not worth the surface area. It can be
  layered on later without reshaping the data, since names already travel
  per-match.

Sub-decisions:

1. **Stamping: watch, at match start.** The synced names are copied into
   `MatchState` when `ScoreView` creates it
   (`watchOS/Views/ScoreView.swift:25`) and travel back in
   `MatchResultPayload`. **History is immutable** — renaming in Settings later
   never rewrites stored matches; each match records the names in effect when
   it was played.
2. **`WatchSettings` payload:** two new fields `teamAName`/`teamBName`,
   default `""`, mirroring the color-sync pattern exactly — fields
   (`Shared/WatchSettings.swift:14-16`), `toApplicationContext()` (`:18-24`),
   `from(_:)` with `?? ""` (`:29-35`), plus two `WatchMessageKey` constants.
   Full-replacement application-context semantics unchanged.
3. **Settings UI: merged "Teams" section.** The existing "Team Colors"
   section (`iOS/Views/SettingsView.swift:38-41`) becomes one "Teams" section:
   per team, a Name `TextField` with the color dots beneath it.
4. **Constraints: trim + 12-char hard cap.** Whitespace trimmed on commit;
   whitespace-only counts as empty (localized fallback). The cap keeps the
   44-pt serve buttons and history score lines from truncating.

Chosen mock:

```
iOS Settings                     Watch: ServeSelectionView
┌──────────────────────────┐     ┌─────────────────────┐
│ Teams                    │     │  Who serves first?  │
│  Team A                  │     │ ┌─────────────────┐ │
│   Name  [Renan        ]  │     │ │     Renan       │ │
│   Color ●●●●●            │     │ └─────────────────┘ │
│  Team B                  │     │ ┌─────────────────┐ │
│   Name  [Visitors     ]  │     │ │    Visitors     │ │
│   Color ●●●●●            │     │ └─────────────────┘ │
└──────────────────────────┘     └─────────────────────┘
                                 (no watch text entry)
```

Views/services that change on this surface:

- `iOS/Views/SettingsView.swift:38-41` — merged Teams section with name fields
- `Shared/WatchSettings.swift:9-36` — two name fields + encode/decode
- `iOS/Services/PhoneSessionManager.swift:10,33` — `@AppStorage` name bindings
  + `WatchSettings` construction
- `watchOS/Services/WatchSessionManager.swift:60-63` — `apply(_:)` publishes
  the names
- `watchOS/Views/ServeSelectionView.swift:24,32` — serve buttons show the
  synced names
- `watchOS/Views/ScoreView.swift:25` — `MatchState` init stamps the names

## 3. Display & localization

### Sites that show the Team Name, falling back to localized "Team A"/"Team B" when empty

| Site | Current code | With names |
|---|---|---|
| `iOS/Views/MatchListView.swift:222` (`MatchRowView.winnerBadge`) | `Text("Team \(match.winner.uppercased()) wins")` | `"<name> wins"`; fallback `"Team A wins"` |
| `iOS/Views/MatchListView.swift:197` (score line) | `Text("A \(match.scoreDisplay) B")` | names flank the score; fallback letters `A`/`B` |
| `iOS/Views/MatchDetailView.swift:21` (Score row) | `Text("A \(match.scoreDisplay) B")` | same as above |
| `iOS/Views/MatchDetailView.swift:28` (Winner row) | `Text("Team \(match.winner.uppercased())")` | name; fallback `"Team A"` |
| `watchOS/Views/ScoreView.swift:236` (match-over banner) | `Text("\(state.winner?.displayName ?? "") wins")` | name from `MatchState`; fallback via `displayName` |
| `watchOS/Views/ServeSelectionView.swift:24,32` (serve buttons) | `teamButton(color:label:)` with literal `"Team A"`/`"Team B"` | default names when set. **Build caveat:** the `label` param is `LocalizedStringKey` (`:44`) — a user name must not go through catalog lookup, so the param becomes `String`/`Text` with the fallback localized before the call. |

### Sites that deliberately keep the single letter

- `iOS/Views/MatchDetailView.swift:95` (per-set badge) and `:138` (per-game
  badge): 22-pt colored circles showing `A`/`B`. Names don't fit; the
  color+letter pair stays the compact identity marker. **No change.**
- `iOS/Views/SettingsView.swift:39-40`: the "Team A"/"Team B" labels in the
  merged Teams section stay localized literals (they label the slot, not the
  match).

### `Team.displayName` (`Shared/MatchState.swift:7-11`)

**Stays, unchanged, as the sole empty-name fallback and localization point.**
The build adds a resolver that prefers a non-empty Team Name and falls back to
`displayName` (`MatchState.teamName(for:)` per §1) — display sites call the
resolver, never `displayName` directly.

### Localization rule

**Team Names are user data and are never translated** — never entered into
`Shared/Localizable.xcstrings`, consistent with CLAUDE.md's
never-translate-persisted-strings rule. The literal `"Team A"`/`"Team B"`
catalog entries remain as the fallback and must not be removed. **Re-key
caveat:** the interpolated sites localize via pattern keys today
(`Team %@ wins` from `MatchListView.swift:222`); replacing the phrase's
subject with a name changes the key structure, so those catalog entries must
be re-keyed in the same commit (CLAUDE.md rule).

### Glossary term

**"Team Name"** for CONTEXT.md: *the user-set label attached to side A or B of
a match; empty means unnamed, and the UI falls back to the localized
"Team A"/"Team B".* Checked against every `_Avoid_` list in CONTEXT.md — no
collision; "Team" itself is not a glossary term today, so no overload.

## 4. Recommendation & build plan

### Go/no-go: **GO**

Every risk the spike was chartered to retire is retired: migration is #47-safe
with property-level defaults, the wire tolerates version skew in both
directions, the UX needs zero watch text entry, and the display inventory is
closed at ten sites. No STOP condition triggered.

### Build-plan outline (one plan, plans 006/010 executor style)

A single M-effort build plan — the surfaces are too entangled for separate PRs
(the wire fields are useless without the display, and stamping needs the
settings sync). Suggested steps:

1. **Shared models + wire** — add the two fields to `MatchState` (with the
   `teamName(for:)` resolver), `MatchResultPayload` (three places, `?? ""`
   decode), and `WatchSettings` (mirroring colors). Unit-test the payload
   round-trip and the old-dictionary fallback alongside the existing
   `MatchResultPayload` tests.
2. **iOS persistence** — `StoredMatch` fields with property-level defaults,
   copied in `StoredMatch(copying:)`, passed through
   `PhoneSessionManager.insertMatch`. Verify migration against a 1.2.x store
   (reviewer scrutiny item) and the Quarantined-Store restore round-trip.
3. **Settings entry + sync** — merged "Teams" section in `SettingsView`
   (TextField, trim, 12-char cap), `@AppStorage` bindings in
   `PhoneSessionManager`, names ride `pushSettingsToWatch()`;
   `WatchSessionManager.apply(_:)` publishes them.
4. **Watch stamping + display** — `ScoreView` stamps the synced names into
   `MatchState` at creation; `ServeSelectionView` buttons (with the
   `LocalizedStringKey` → `String` param change) and the match-over banner
   show names via the resolver.
5. **iOS display + localization re-key + docs** — the four iOS list/detail
   sites switch to the resolver with fallbacks; re-key the affected catalog
   entries in the same commit; add "Team Name" to CONTEXT.md.

Steps 1–2 are the risk core; 3–5 are additive UI. The plan needs no
`xcodegen generate` unless the build adds files.

### Effort per surface

| Surface | Effort | Notes |
|---|---|---|
| Watch (settings receive, stamping, 2 display sites) | **S** | mirrors the existing color-sync path exactly |
| Wire (`MatchResultPayload` + `WatchSettings`) | **S** | mechanical "field in three places" ×2, plus tests |
| iOS persistence (`StoredMatch` + migration) | **S** | small diff, but carries the migration-review burden |
| iOS display + localization re-key | **M** | four sites, catalog re-keying, fallback discipline |

Whole build: **M**, one PR.

### Ordered dependency

Names must land **before plan 017** (stats gain per-player value only with
names) and **before plan 018** (the share card should show names). Both still
function anonymously without it, so this orders value, not feasibility.

### Explicit non-goals

Out of scope for the build this design spawns (per the spike's maintenance
notes): **avatars/photos**, **more than two teams**, and **doubles (four
individual player names)**. A future doubles feature would add fields, not
reshape these.
