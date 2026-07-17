# Plan 016: Design a HealthKit workout session on the watch (spike — decide feasibility + shape, do NOT ship)

> **Executor instructions**: This is a **design spike**, not a build task. Your
> deliverable is a written design document plus a go/no-go recommendation. You
> will **not** modify any Swift source, `project.yml`, entitlements, or Info
> plists. Follow the steps, ground every claim in the actual files, and write
> the design file named in "Done criteria". If a STOP condition occurs, stop and
> report. When done, update this plan's row in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 9d05103..HEAD -- BeachTennisCounter/watchOS/Views/ScoreView.swift BeachTennisCounter/watchOS/Services/WatchSessionManager.swift BeachTennisCounter/project.yml`
> If any of these changed since this plan was written, compare the "Current
> state" excerpts against the live code before proceeding; note any mismatch in
> the design doc.

## Status

- **Priority**: P2
- **Effort**: L (the spike is S–M; the build it designs is M–L and needs device testing)
- **Risk**: LOW (design-only; ships nothing)
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `9d05103`, 2026-07-17

## Why this matters

The app is a watch-first scorer for a physically demanding sport, yet it gives
the player **zero fitness credit** for a match. Match duration is tracked as
plain wall-clock time (`ScoreView.swift:52`,
`Date().timeIntervalSince(state.matchStartDate)`), there is **no** HealthKit
entitlement on the watch target (`project.yml:67-89` has none), and there is no
`WKExtendedRuntimeSession` or workout session anywhere in the repo. Starting an
`HKWorkoutSession` while a match is scored would: (1) earn Activity-ring /
exercise-minute credit, (2) surface heart rate and estimated calories, and
(3) — the operational win — keep the watch app alive and foregrounded for the
duration via the workout's runtime, which today it does not guarantee. This is
the single most impactful watchOS-native capability a sports scorer can add, and
it sits directly on top of data the app already computes. But HealthKit brings a
new entitlement, a permission prompt, required-reason privacy strings, and
behavior that is thin/unreliable in the Simulator — so the responsible first
step is a feasibility spike, not a blind build.

## Current state

- **Duration is wall-clock, no workout.** `watchOS/Views/ScoreView.swift`:
  - line 30 — `s.matchStartDate = Date()` (match start, in `init`)
  - lines 49-53 — match end fires once, computing duration from timestamps:

```swift
.onChange(of: state.isMatchOver) { _, isOver in
    guard isOver else { return }
    showMatchOver = true
    sessionManager.sendMatchResult(state, duration: Date().timeIntervalSince(state.matchStartDate))
}
```

  These two points (`matchStartDate` set, `isMatchOver` transition) are the
  natural **start/stop hooks** for a workout session. There is also a
  cancel/end-match path via `showCancelAlert` (`ScoreView.swift:58-60`) and a
  resume path (a match can be restored mid-play — `HomeView.swift:64-72`), both
  of which a workout session must account for (start on resume, end on cancel).

- **No HealthKit anywhere.** The only WatchKit API currently used is haptics
  (`ScoreView.swift:271,278` — `WKInterfaceDevice.current().play(.click)`).
  There is no `import HealthKit`, no `HKHealthStore`, no `HKWorkoutSession`.
- **The watch target has no health entitlement or background mode.**
  `project.yml:67-89` (the `BeachTennisCounterWatch` target) declares
  `WKApplication`, `WKRunsIndependentlyOfCompanionApp`, and a companion bundle
  id — but **no** entitlements block and **no** `WKBackgroundModes`. A workout
  session requires the HealthKit entitlement and (for the
  `HKWorkoutSession`/`HKLiveWorkoutBuilder` path) the workout-processing
  background mode. The watch also currently has **no** `PrivacyInfo.xcprivacy`
  health usage strings; `NSHealthShareUsageDescription` /
  `NSHealthUpdateUsageDescription` live in the Info.plist, which the watch
  target generates from `project.yml` `info.properties` (see the iOS target's
  `info.properties` at lines 43-52 for the pattern).
- **Convention: watch session state is centralized.**
  `watchOS/Services/WatchSessionManager.swift` is the `@MainActor` singleton
  that owns cross-cutting watch runtime concerns (WCSession). A workout manager,
  if built, would follow that shape (a `@MainActor` object owning the
  `HKWorkoutSession`), injected the same way `WatchSessionManager` is.
- **Deployment target is watchOS 26.0** (`project.yml:5`), so the modern
  `HKWorkoutSession` + `HKLiveWorkoutBuilder` API (and Simulator workout support
  where it exists) is available — no back-deployment concerns.
- **No native "beach tennis" activity type.** HealthKit has no beach-tennis
  `HKWorkoutActivityType`; `.tennis` is the closest. The design must pick and
  justify (`.tennis` for both modes is the pragmatic choice).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Drift check | `git diff --stat 9d05103..HEAD -- BeachTennisCounter/watchOS/Views/ScoreView.swift BeachTennisCounter/project.yml` | empty (no drift) |
| Confirm no source changed | `git status --porcelain BeachTennisCounter/` | empty at the end of the spike |

No build/test — the spike writes no code.

## Scope

**In scope** (the only file you create):
- `plans/016-healthkit-workout-design.md` — the design deliverable.

**Out of scope** (do NOT modify):
- Every `.swift` file, `project.yml`, `*.entitlements`, `Info.plist`,
  `PrivacyInfo.xcprivacy`. The spike *recommends*; a later build plan makes the
  changes. If you start editing these, STOP.

## Git workflow

- Branch: `advisor/016-healthkit-workout-spike`
- Commit style: `docs(spike): design HealthKit workout session on watch`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Confirm the entitlement, capability, and privacy-string requirements

In `plans/016-healthkit-workout-design.md`, list exactly what the watch target
must gain, each as the concrete `project.yml`/plist change a build plan would
make:
- HealthKit entitlement (`com.apple.developer.healthkit`) on
  `BeachTennisCounterWatch` — note the target has no entitlements block today
  (`project.yml:67-89`), so one is added, mirroring the iOS target's
  `entitlements:` block shape at lines 53-57.
- The workout background mode (`WKBackgroundModes: [workout-processing]`) in the
  watch `info.properties`.
- `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` strings
  (localized — pt-BR is a known region, `project.yml:10-13`), and whether a
  watch `PrivacyInfo.xcprivacy` needs a required-reason entry (compare how
  plan 013 handled the iOS File Timestamp manifest — check whether HealthKit
  read/write needs an analogous declaration).
- The **App Store review** implication: a HealthKit entitlement adds review
  scrutiny and requires the usage strings to be truthful. Note it; do not
  hand-wave it.

**Verify**: the file enumerates every entitlement/plist/privacy change with the
target it applies to.

### Step 2: Design the session lifecycle against the real hooks

Map the workout session lifecycle onto `ScoreView`'s existing state
transitions, citing lines:
- **Start**: when the match begins (`matchStartDate` set, `ScoreView.swift:30`)
  or `ScoreView.onAppear` — decide which and why. Must also start when a match is
  **resumed** (`HomeView.swift:64-72` → `ScoreView` with `restoredState`).
- **End**: on `isMatchOver` transition (`ScoreView.swift:49-53`) — end and save
  the workout; decide the relationship to the existing `sendMatchResult` call.
- **Cancel**: on the "Cancel Match?" path (`ScoreView.swift:58-60`) — end the
  workout **without** saving a completed match, or discard it. Specify.
- Authorization: when to request it (first match vs. app launch), and the
  graceful-degradation rule — **scoring must work unchanged if the user denies
  HealthKit.** State this as a hard requirement.

**Verify**: the file has a lifecycle table (event → session action → source
`file:line`), and an explicit "denied authorization ⇒ scoring unaffected" rule.

### Step 3: Decide what workout data flows into Match History (if any)

Today `MatchResultPayload` carries duration (`WatchMessage.swift:33`). Decide
whether the workout adds anything to the stored match (e.g. active calories,
average heart rate) or stays purely a Health-app-side artifact. If it adds
fields, note that this pulls in the same 3-place wire change +
`StoredMatch`-migration considerations documented in plan 015 (cross-reference
it; the #47 property-default rule applies). A defensible v1 is: workout writes
to Health only, `StoredMatch` unchanged — lowest risk. Recommend and justify.

**Verify**: the file states whether `StoredMatch`/`MatchResultPayload` change,
and if so cross-references plan 015's migration rule.

### Step 4: Feasibility verdict, Simulator caveat, and build outline

Close with:
- A **go/no-go** recommendation and the coarse effort (S/M/L) per surface
  (entitlements/plist, workout manager object, ScoreView wiring, authorization
  UX).
- The **verification reality**: HealthKit workout sessions are thin/unreliable
  in the watch Simulator; state that the build plan's real verification is
  on-device, and that CI (`xcodebuild test` on the iOS simulator scheme, per
  CLAUDE.md) will only cover that it compiles, not that a workout records. This
  is why it is a spike first.
- A 4–6 step outline of the build plan this would spawn, in plans 006/007's
  concrete style.

**Verify**: `git status --porcelain BeachTennisCounter/` is empty and
`plans/016-healthkit-workout-design.md` exists.

## Test plan

None — a spike ships no code. The deliverable is the design document; its
acceptance test is that a maintainer can make a go/no-go call and, on "go",
hand the build outline to an executor without re-researching entitlements.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `plans/016-healthkit-workout-design.md` exists with four sections matching
      Steps 1–4.
- [ ] It enumerates the exact entitlement + `WKBackgroundModes` +
      usage-description changes per target.
- [ ] It contains a lifecycle table tied to real `ScoreView` `file:line` hooks
      and the "denied auth ⇒ scoring unaffected" rule.
- [ ] It states the Simulator/on-device verification reality explicitly.
- [ ] `git status --porcelain BeachTennisCounter/` is empty.
- [ ] `plans/README.md` status row for 016 updated.

## STOP conditions

Stop and report back (do not improvise) if:

- You determine an Apple Developer **paid membership / provisioning** with the
  HealthKit capability is required to even build/sign with the entitlement, and
  it is unclear the maintainer has it — the build plan is blocked on account
  setup, and the maintainer must confirm before it is worth writing.
- The `ScoreView` start/end/cancel hooks in "Current state" have been refactored
  away (drift check failed) so the lifecycle mapping no longer holds.
- You start writing Swift, editing `project.yml`, entitlements, or plists — that
  is the build plan's job.

## Maintenance notes

- The build plan must verify the migration-free claim on a real device and
  confirm scoring is untouched when HealthKit is denied — both are the review
  hot spots.
- Explicit non-goals to record in the design doc: no route/GPS, no
  swimming/other sports, no retroactive workout for matches scored before the
  feature shipped, no complications (that is plan 019's separate surface).
- Cross-plan: if plan 015 (named teams) adds `StoredMatch` fields first, and
  this plan also adds workout fields, the two migrations should land in a single
  coordinated schema bump — note the ordering when both are greenlit.
