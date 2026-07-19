# Plan 019: Add a watchOS complication that quick-launches the app

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. This plan **adds a new build target** — read the whole plan,
> especially the STOP conditions, before starting. If anything in "STOP
> conditions" occurs, stop and report — do not improvise. When done, update the
> status row for this plan in `plans/README.md` — unless a reviewer dispatched
> you and told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9d05103..HEAD -- BeachTennisCounter/project.yml BeachTennisCounter/watchOS/Views/HomeView.swift`
> If either changed since this plan was written, compare the "Current state"
> excerpts against the live code before proceeding; on a mismatch, treat it as a
> STOP condition.

## Status

- **Priority**: P3
- **Effort**: M (dominated by adding + wiring a new WidgetKit target)
- **Risk**: MED (new target + code signing; the *code* is tiny, the *project
  plumbing* is where this can go wrong)
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `9d05103`, 2026-07-17

## Why this matters

The app is watch-first: a player raises their wrist to start scoring. But there
is no watch-face presence — no complication, no Smart Stack widget — so starting
a match means finding the app in the grid first. A single **corner/circular
complication that launches the app** puts a one-tap entry point on the watch
face, landing the player directly on `HomeView`, whose primary control is
already a large "New Match" button (`HomeView.swift:16-36`). This is the
smallest possible occupation of a valuable native surface the app doesn't yet
use. Scope is deliberately minimal: a launch complication, **not** a data
complication (which would need a shared data source and timeline updates).

## Current state

- **There is no widget/complication target today.** `project.yml:21-89` declares
  exactly three targets: `BeachTennisCounterTests`, `BeachTennisCounter` (iOS),
  `BeachTennisCounterWatch` (watchOS). There is no `import WidgetKit` anywhere
  (`grep -rn "WidgetKit\|WidgetBundle\|ClockKit" BeachTennisCounter` → nothing).
- **The watch target is a standalone WKApplication** (`project.yml:67-89`):

```yaml
BeachTennisCounterWatch:
  type: application
  platform: watchOS
  deploymentTarget: "26.0"
  ...
  properties:
    WKApplication: true
    WKRunsIndependentlyOfCompanionApp: true
    PRODUCT_BUNDLE_IDENTIFIER: com.renan.beachtennis.watchkitapp
```

  A watchOS **widget extension** is a *separate* target
  (`type: app-extension` / `com.apple.widgetkit-extension`) embedded in the
  watch app, with its own bundle id (conventionally
  `com.renan.beachtennis.watchkitapp.complication`) and its own Info.plist
  `NSExtension` block. It is added to `project.yml` and picked up by
  `xcodegen generate`.
- **Landing screen is already one tap from a new match.** `watchOS/Views/HomeView.swift:16-36`
  is a `NavigationStack` whose main control is the "New Match" button. Simply
  **launching the app** (a complication with no deep-link) puts the user here —
  which is why v1 needs no URL handling.
- **Deployment target watchOS 26.0** (`project.yml:5`) → modern SwiftUI
  WidgetKit complications (`accessoryCircular`/`accessoryCorner` families) are
  available; ClockKit is not needed.
- **Convention**: `xcodegen generate` is mandatory after any structural change
  (new target, new file) — CLAUDE.md. The watch-only build is the fast gate:
  `xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Regenerate project (mandatory after adding the target/files) | `cd BeachTennisCounter && xcodegen generate` | `Created project at …` |
| Watch build gate | `cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build` | `** BUILD SUCCEEDED **` |
| Widget-extension build gate | `cd BeachTennisCounter && xcodebuild -target <WidgetTargetName> -sdk watchsimulator build` | `** BUILD SUCCEEDED **` |
| Full test gate (does not regress) | `cd BeachTennisCounter && xcodebuild test -project BeachTennisCounter.xcodeproj -scheme BeachTennisCounter -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |

Substitute an available device from `xcrun simctl list devices available` if
`iPhone 17` is absent.

## Scope

**In scope**:
- `BeachTennisCounter/project.yml` — add the watchOS widget-extension target and
  embed it in `BeachTennisCounterWatch`.
- `BeachTennisCounter/watchOS/Complication/` (create) — the widget source:
  a `@main` `WidgetBundle` (or single `Widget`), a `TimelineProvider` with a
  single static entry, and the SwiftUI view for the supported accessory families.
- `BeachTennisCounter/watchOS/Complication/Info.plist` (create) if xcodegen does
  not synthesize the extension `NSExtension` keys — follow the generated-plist
  pattern the watch target uses (`project.yml:74-84` `info.properties`).

**Out of scope** (do NOT touch):
- Any **data** on the complication (last score, win count, etc.) — v1 is a
  launch glyph with a static timeline. A data complication needs a shared
  App-Group data read and timeline reloads; that is a separate plan.
- **Deep-linking** into a specific screen (straight to serve-selection). v1
  launches the app to `HomeView` (already one tap from New Match). URL/App-Intent
  deep-linking is a deferred follow-up.
- iOS widgets / Lock Screen widgets — this plan is the watch face only.
- `HomeView.swift` and all scoring code — no changes; launching the app is the
  default complication behavior.

## Git workflow

- Branch: `advisor/019-watch-quicklaunch-complication`
- Commit style: `feat(watch): add a face complication that launches the app`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add the widget-extension target to project.yml

Add a new target (name it e.g. `BeachTennisWatchComplication`) of an
app-extension type embedded in the watch app. It needs: platform `watchOS`,
`deploymentTarget "26.0"`, its own `PRODUCT_BUNDLE_IDENTIFIER`
(`com.renan.beachtennis.watchkitapp.complication`), an `NSExtension` Info.plist
block declaring `com.apple.widgetkit-extension`, and it must be listed as an
embedded dependency of `BeachTennisCounterWatch`. Mirror the existing targets'
`info.properties` / `settings.base` style (`project.yml:34-89`). Add the new
target to the `BeachTennisCounterWatch` scheme's build targets if a scheme lists
them explicitly.

**Verify**: `grep -n "widgetkit-extension\|Complication" BeachTennisCounter/project.yml` → the new target block.

### Step 2: Write the widget source (static launch complication)

Create the widget under `watchOS/Complication/`:
- A `@main struct … : Widget` (or a `WidgetBundle` containing it) with a
  `StaticConfiguration`.
- A `TimelineProvider` returning a **single** timeline entry (no dynamic data,
  `.never` reload policy) — this is a launch button, not a data readout.
- A view supporting at least `.accessoryCircular` (and optionally
  `.accessoryCorner`) rendering the app glyph (SF Symbol matching the app —
  `beach.umbrella` or `tennis.racket`, consistent with `MatchType.icon` in
  `MatchState.swift:25-30`).
- `.supportedFamilies([.accessoryCircular])` at minimum.

Keep the source small and self-contained; it imports `WidgetKit` + `SwiftUI`
only. It does **not** import the app's models unless it renders data (it does
not, in v1).

**Verify**: `grep -rn "@main\|StaticConfiguration\|accessoryCircular" BeachTennisCounter/watchOS/Complication/` → the widget definition.

### Step 3: Regenerate and build the extension

```
cd BeachTennisCounter && xcodegen generate
```

Then build the widget target and the watch app:

```
cd BeachTennisCounter && xcodebuild -target BeachTennisWatchComplication -sdk watchsimulator build
cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build
```

**Verify**: both print `** BUILD SUCCEEDED **`. If code signing blocks the
extension build in this environment, see STOP conditions.

### Step 4: Confirm the app test suite still passes

Run the full test command. The complication adds no logic to the tested target;
this step only proves the project restructure didn't break the app build/tests.

**Verify**: `** TEST SUCCEEDED **`.

## Test plan

No unit tests: a launch complication is declarative WidgetKit + SwiftUI with no
logic seam (consistent with plans 010/018 — no UI-test infra in this repo). The
gates are the extension build (Step 3) and the non-regression test run (Step 4).
Manual QA note for the operator: add the complication to a watch face in the
simulator/device → tapping it opens the app on `HomeView` with the New Match
button visible.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -c "widgetkit-extension" BeachTennisCounter/project.yml` → ≥ 1
- [ ] Widget source exists under `BeachTennisCounter/watchOS/Complication/` with
      a `@main` widget and `.accessoryCircular` support.
- [ ] `xcodebuild -target BeachTennisWatchComplication -sdk watchsimulator build` → `** BUILD SUCCEEDED **`
- [ ] `xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build` → `** BUILD SUCCEEDED **`
- [ ] Full test command → `** TEST SUCCEEDED **`
- [ ] `git status` shows changes only to `project.yml`, the new
      `watchOS/Complication/` files, and the regenerated `.xcodeproj`.
- [ ] `plans/README.md` status row for 019 updated.

## STOP conditions

Stop and report back (do not improvise) if:

- The widget-extension **build fails on code signing / provisioning** that can't
  be satisfied with `CODE_SIGNING_ALLOWED=NO` in this environment — adding an
  embedded extension can require a provisioning profile the CI/local setup
  doesn't have. Report the exact error; the maintainer may need to configure
  signing before this can land. Do **not** disable signing app-wide or fake a
  profile to get past it.
- `xcodegen generate` errors on the new target definition (report the exact
  message — the target-type/extension-point spelling is the likely culprit).
- You find yourself reading match data into the complication, or adding
  URL/App-Intent deep-linking — both are out of scope; v1 is a static launch
  glyph.
- The watch target's structure in `project.yml` has drifted from the "Current
  state" excerpt.

## Maintenance notes

- The obvious follow-ups (each its own plan): a **data** complication showing
  last result / matches-this-week (needs an App-Group shared read — the group
  `group.com.renan.beachtennis` already exists, `project.yml:56-57`), and
  **deep-linking** the tap straight into serve-selection via an App Intent or
  URL handled in `HomeView`.
- Reviewer should scrutinize: the extension's bundle id nests under the watch
  app's id, the extension is embedded in (not just depended on by) the watch
  target, and the app's own build/tests are unchanged.
- If a data complication is later added, it and any HealthKit work (plan 016)
  both touch the watch target's capabilities — coordinate the `project.yml`
  edits to avoid churn.
