# Research: How much of the HKWorkoutSession path is verifiable in the watch Simulator (plan 016 spike)

**Question**: When the watch app starts an `HKWorkoutSession` + `HKLiveWorkoutBuilder`
while scoring a match, which parts of that path can be verified in the watchOS 26
Simulator, and which parts must wait for a physical Apple Watch?

**Scope**: research only; nothing applied. Written to feed the "device-testing
protocol" section of the 016 build plan. Every claim is tagged **[documented]**
(Apple primary source), **[community]** (developer-forum / third-party reports,
anecdotal), or **[unverified]** (no source found either way — needs a quick
empirical check). Freshness caveat: Apple's clearest statement about simulated
workout data is from WWDC21 (watchOS 8 era); no Xcode 16/17/26 release note
contradicts or supersedes it, but nothing re-confirms it for watchOS 26 either, so
first-run smoke checks are listed where that matters.

---

## 1. Summary table — Simulator-verifiable vs device-only

| Concern | Simulator? | Confidence | Notes |
|---|---|---|---|
| `HKHealthStore.isHealthDataAvailable()` returns `true` on watch sim | Yes | High [community + doc inference] | Apple lists the `false` cases (iPadOS ≤ 16, macOS, enterprise-restricted); watch/iOS sims are not among them, and community threads show HealthKit reads/writes working in the sim (§5) |
| Authorization prompt flow (`requestAuthorization`) | Yes | High [community] | Sheet appears in the sim; reset with "Erase All Content and Settings" or a fresh sim to re-test first-run (§5) |
| `HKWorkoutSession` start / pause / resume / end lifecycle + state delegate callbacks | Yes | High [documented, WWDC21] | Apple demoed the full flow in the watchOS Simulator (§2) |
| `HKLiveWorkoutBuilder` collection, `didCollectDataOf` callbacks | Yes | High [documented, WWDC21] | Requires `HKLiveWorkoutDataSource` attached and read permission granted, else no callbacks (§3) |
| Simulated live heart rate / active energy / distance samples | Yes | Medium-High [documented WWDC21; re-confirm on watchOS 26] | "The watchOS simulator automatically simulates collecting live workout samples for you" (§3). Values are synthetic, not configurable |
| Saving the finished `HKWorkout` and re-querying it | Yes | High [community, incl. Apple engineer reply] | Writes to the sim Health store work and are queryable (§5) |
| Seeding arbitrary test samples via Health app UI on the paired iOS sim | Yes (iOS side) | Medium [community] | iOS Simulator ships the Health app; Browse → category → Add Data. No Health app on the watch sim itself (§5) |
| Health-store sync between paired watch sim and iPhone sim | Probably not | Low [unverified] | Treat each sim's store as isolated until empirically checked (§5) |
| Activity-ring / Fitness-app credit for the finished workout | No (practically) | Medium [community + absence of sim Fitness app] | No Fitness app in either simulator; ring credit must be observed on device. `HKActivitySummaryQuery` is the only sim-side probe and its behavior there is [unverified] (§4) |
| Real sensor values (plausible HR curves, calorie accuracy) | Device only | High [documented] | Simulator has no hardware sensors at all (§6) |
| `workout-processing` background-mode runtime behavior (app stays frontmost, survives wrist-down) | Device only | High [documented-by-omission + community] | Wrist-down/always-on semantics don't exist in the sim (§6) |
| Battery / thermal impact of a long session | Device only | High [documented] | Simulator does not reproduce thermal/power behavior (§6) |
| `WCSession.transferFile` (not used by this app; `transferUserInfo` is) | Device only | Medium [community] | Known sim limitation; verify our `transferUserInfo` path in the sim as today (§6) |

---

## 2. Session lifecycle in the Simulator — works

Apple's own WWDC21 walkthrough of a watch workout app runs the whole
`HKWorkoutSession` + `HKLiveWorkoutBuilder` flow **in the watchOS Simulator**,
including start, the paired builder's `beginCollection`, pause/resume via the
session state machine, and `end` → `finishWorkout`. The presenter narrates the
sim run directly: "Notice that elapsed time is incrementing." **[documented]**
Source: WWDC21 "Build a workout app for Apple Watch" —
<https://developer.apple.com/videos/play/wwdc2021/10009/>

Neither the `HKWorkoutSession` nor the `HKLiveWorkoutBuilder` reference pages
carry any "device-only" caveat (contrast with APIs Apple does flag, e.g. session
mirroring pitfalls). **[documented-by-omission]**
Sources: <https://developer.apple.com/documentation/healthkit/hkworkoutsession>,
<https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilder>,
<https://developer.apple.com/documentation/HealthKit/running-workout-sessions>

Verifiable in the sim: session state transitions and
`workoutSession(_:didChangeTo:from:date:)` delegate ordering, the
pause/resume/end UI wiring in `ScoreView`, and error paths from
`beginCollection`/`endCollection`.

## 3. Live builder samples — the simulator synthesizes them

Apple, in the same WWDC21 sim demo: **"The watchOS simulator automatically
simulates collecting live workout samples for you. Calories are accruing. Heart
rate is updating. Distance is accumulating."** **[documented]**
Source: <https://developer.apple.com/videos/play/wwdc2021/10009/>

Practical conditions, from community reports **[community]**:

- Samples only flow if an `HKLiveWorkoutDataSource` is attached to the builder
  *and* read authorization for those quantity types was granted — a missing
  grant silently yields no `didCollectDataOf` callbacks, in the sim and on
  device alike. Source: Apple Developer Forums, "HKLiveWorkoutBuilder only
  reporting…" — <https://developer.apple.com/forums/thread/764078> (thread
  answer notes "The simulator did generate heart rate samples").
- The synthetic values are fixed-pattern, not configurable; they exercise the
  code path (statistics, unit conversion, UI updates) but say nothing about
  realistic values.

**What Xcode did *not* add:** searches of the Xcode 16/17/26-era release notes
turned up no feature named "simulated workout data" or any new simulator health
data generator. The only documented simulator sample-data facility is
**clinical records** (FHIR sample accounts) — static, medical-records-only, and
explicitly unrelated to workouts or heart rate. **[documented]**
Sources: "Accessing Sample Data in the Simulator" —
<https://developer.apple.com/documentation/healthkit/accessing-sample-data-in-the-simulator>;
Xcode 26 release notes index —
<https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes>
(HealthKit entries there are new reproductive-health sample types, nothing
simulator-related).

So the WWDC21 behavior is the current state of the art. First sim run of the 016
build should include a 60-second smoke check that `didCollectDataOf` fires with
heart rate and active energy on the watchOS 26 sim; if it doesn't, that moves to
the device-only column rather than blocking the build.

## 4. Activity-ring credit — device-only in practice

- Neither the iOS Simulator nor the watchOS Simulator ships the Fitness /
  Activity app, so there is no UI in which to *see* ring credit.
  **[community / absence-of-feature]** (No Apple doc claims otherwise; the
  simulator stock-app set is reduced, and no search result shows a sim Fitness
  app.)
- The programmatic probe would be `HKActivitySummaryQuery` (requires read
  authorization for `HKObjectType.activitySummaryType()`). Whether the
  simulator's health daemon maintains activity summaries from a finished
  workout's active-energy samples is **[unverified]** — no primary or community
  source found either way. Worth one empirical attempt; expect empty results.
  Source (API): "Workouts and activity rings" —
  <https://developer.apple.com/documentation/healthkit/workouts-and-activity-rings>
- Even on device, ring credit is a known soft spot: forum reports of "data
  missing in the Fitness app and Activity Rings failing to fill" after a watch
  `HKWorkoutSession` are common enough to make ring credit an explicit
  device-test item, not an assumed consequence of `finishWorkout`.
  **[community]** Source: Apple Developer Forums Health & Fitness tag —
  <https://developer.apple.com/forums/tags/health-and-fitness>

Device protocol implication: verify on a real watch that a finished match
workout (a) appears in Fitness with correct activity type/duration, (b) fills
Exercise and Move rings, and (c) shows the app's name as the source.

## 5. HealthKit availability, authorization, and seeding data in the sim

- **`isHealthDataAvailable()`**: Apple documents `false` only for iPadOS 16 and
  earlier, macOS (Catalyst/Designed-for-iPad style targets), and
  enterprise-restricted devices; "By default, HealthKit data is available on
  iOS, watchOS, and visionOS." No simulator exception is documented.
  **[documented]** Source:
  <https://developer.apple.com/documentation/healthkit/hkhealthstore/ishealthdataavailable()>
- **The sim Health store is real and writable**: in an Apple Developer Forums
  thread, a developer saves workouts from the Simulator, views them in the
  Simulator's Health app, and an Apple Frameworks Engineer debugs the query
  logic without ever suggesting the simulator is the problem — i.e. write +
  read against the sim store is the expected workflow. **[community, with
  Apple-engineer participation]** Source:
  <https://developer.apple.com/forums/thread/692302>
- **Authorization prompts** present normally in the sim (standard tutorial
  workflow; e.g. Kodeco's watchOS HealthKit chapters drive the grant flow in
  the simulator). One caveat from the same source: on the watch side you can't
  launch a Health app to review grants — "While the simulator can read and
  write to Apple Health, you can't launch the Apple Health app yourself."
  **[community]** Source:
  <https://www.kodeco.com/books/watchos-with-swiftui-by-tutorials/v2.0/chapters/12-healthkit>
- **Seeding test samples**: the *iOS* Simulator's Health app allows manual data
  entry (Browse → category → Add Data), and code-based seeding via
  `HKHealthStore.save(_:)` works (thread above). **[community]**
- **Paired-sim sync**: no source confirms that a workout saved in the watch
  sim's store appears in the paired iPhone sim's Health app; on real hardware
  that sync is an OS service, and the simulators are widely assumed to keep
  isolated stores. Treat as **[unverified]**; the 016 plan should not depend on
  it (this app's watch→phone result path is `WCSession.transferUserInfo`, not
  HealthKit sync, so nothing in the current architecture needs it).

## 6. Device-only items and known quirks

**Device-only by construction [documented]** — Apple's Simulator-vs-hardware
guidance: the Simulator does not reproduce hardware sensors, motion, Bluetooth,
thermal behavior, or real performance characteristics. Source: "Testing in
Simulator versus testing on hardware devices" —
<https://developer.apple.com/documentation/xcode/testing-in-simulator-versus-testing-on-hardware-devices>

Concretely for plan 016, only a physical Apple Watch can verify:

1. **Real sensor samples** — plausible heart-rate curves during actual play,
   calorie estimates driven by the user's Health profile.
2. **Ring / Fitness credit** (§4).
3. **`workout-processing` background-mode semantics** — the app staying the
   frontmost/returnable app during wrist-down, always-on display dimming
   behavior, session survival across long matches. The simulator has no
   wrist-down or always-on states to exercise.
4. **Battery and thermal cost** of a 30–60 min session driving live UI updates.
5. **Watch↔iPhone behavior with only one side present** (phone out of range),
   plus `WCSession.transferFile` if ever adopted — transferFile is reported not
   to work simulator-to-simulator. **[community]** Source:
   <https://fatbobman.com/en/posts/watchos-development-pitfalls-and-practical-tips>

**Known quirks / crash reports on recent versions [community, anecdotal]:**

- "Workout session not current" errors when stopping a session, occasionally
  alongside a HealthKit process crash. Source:
  <https://developer.apple.com/forums/thread/31339> (old thread, but the
  symptom recurs in newer tag listings:
  <https://developer.apple.com/forums/tags/health-and-fitness>)
- `HKWorkoutSession.sendToRemoteWorkoutSession(data:)` (mirroring API — not
  used by 016) intermittently never returns on watchOS 10/11. Source:
  <https://developer.apple.com/forums/thread/769355>
- `HKWorkoutRouteBuilder.insertRouteData` hanging **on the simulator**
  specifically (route building — not used by 016). Evidenced in the watchOS
  forum tag listings above. Net: the non-GPS, non-mirrored path 016 uses is the
  least quirk-prone slice of the API.

## 7. Suggested split for the build plan's device-testing protocol

**Sim-verifiable (CI-adjacent, every iteration):** authorization prompt +
denial handling; session start/pause/end state machine; builder callbacks
updating the score UI; `finishWorkout` producing a queryable `HKWorkout` with
duration/energy; undo/score logic unaffected by the session.

**One-time sim smoke checks (watchOS 26 freshness):** `didCollectDataOf`
delivers heart rate + active energy within ~60 s of `beginCollection`;
`isHealthDataAvailable()` is `true`; `HKActivitySummaryQuery` result shape.

**Device-only checklist (pre-release):** ring/Fitness credit and source
attribution; realistic sensor values; wrist-down survival over a full match;
battery drain over 45 min; behavior with iPhone absent.

---

*Related: `docs/research/016-healthkit-watch-entitlements.md` (entitlement,
Info.plist, and background-mode changes the same plan requires).*
