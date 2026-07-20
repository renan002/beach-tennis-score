# Design 016: HealthKit workout session on the watch (spike deliverable)

> Deliverable of [plan 016](016-healthkit-workout-spike.md) (design spike, ships
> no code). Decisions were resolved on the wayfinder map
> [#63](https://github.com/renan002/beach-tennis-score/issues/63) — account
> capability ([#65](https://github.com/renan002/beach-tennis-score/issues/65)),
> entitlements research ([#64](https://github.com/renan002/beach-tennis-score/issues/64)),
> Simulator reliability ([#66](https://github.com/renan002/beach-tennis-score/issues/66)),
> session lifecycle ([#71](https://github.com/renan002/beach-tennis-score/issues/71)),
> Match History data ([#72](https://github.com/renan002/beach-tennis-score/issues/72)),
> live-metrics prototype ([#93](https://github.com/renan002/beach-tennis-score/issues/93)),
> authorization/denial UX ([#94](https://github.com/renan002/beach-tennis-score/issues/94)),
> and the Health Monitoring toggle ([#95](https://github.com/renan002/beach-tennis-score/issues/95)).
> Research assets: [entitlements](../docs/research/016-healthkit-watch-entitlements.md)
> and [Simulator reliability](../docs/research/016-healthkit-simulator-reliability.md).
> Drift check (`git diff --stat 9d05103..HEAD` over `ScoreView.swift`,
> `WatchSessionManager.swift`, `project.yml`) at design time showed only the
> 1.3.1 version-number bump in `project.yml`; every `file:line` below cites the
> live code.

**Hard requirement carried through every section: scoring must work unchanged
if the user denies HealthKit (or turns Health Monitoring off).**

## 1. Entitlements, capabilities, and privacy strings

The **watch target** (`BeachTennisCounterWatch`, `project.yml:67-89`) gains
exactly three things, all expressed in `project.yml`. The **iOS target changes
only for the Settings toggle UI (§3)** — it never calls HealthKit, so it gains
no entitlement, no background mode, no usage strings.

| # | Change | Where | Detail |
|---|---|---|---|
| 1 | HealthKit entitlement | new `entitlements:` block on the watch target, mirroring the iOS target's shape (`project.yml:53-57`), `path: watchOS/BeachTennisCounterWatch.entitlements` | Single key `com.apple.developer.healthkit: true`. Neither `.access` (FHIR clinical records only) nor `.background-delivery` (observer queries only) is needed. XcodeGen generates the file and sets `CODE_SIGN_ENTITLEMENTS`. |
| 2 | Workout background mode | watch target `info.properties` | `WKBackgroundModes: [workout-processing]` — mandatory for the `HKWorkoutSession` path per Apple's "Running workout sessions". |
| 3 | Usage strings | watch target `info.properties` (en) + `watchOS/pt-BR.lproj/InfoPlist.strings` (pt-BR, two appended lines — file already exists, no new files) | Both `NSHealthShareUsageDescription` (reads heart rate + active energy) and `NSHealthUpdateUsageDescription` (saves the workout). watchOS 6+ authorizes on-watch; the iOS companion needs neither. Final copy below. |

Final usage-string copy (#94; supersedes the #64 draft — it now promises
exactly what ships: live heart rate on the watch, stats in Match History):

- `NSHealthShareUsageDescription`
  - en: `Beach Tennis Score reads your heart rate and calories during a match to show your heart rate live and record your workout stats.`
  - pt-BR: `O Placar Beach Tennis lê sua frequência cardíaca e calorias durante a partida para mostrar a frequência cardíaca em tempo real e registrar as estatísticas do treino.`
- `NSHealthUpdateUsageDescription`
  - en: `Beach Tennis Score saves each match as a workout in the Health app so you get activity credit.`
  - pt-BR: `O Placar Beach Tennis salva cada partida como um treino no app Saúde para você ganhar crédito de atividade.`

**Privacy manifests: no change to either target.** HealthKit is not a
required-reason API category, and on-device HealthKit data is not "collected"
per Apple's definition, so `NSPrivacyCollectedDataTypes` stays empty and "Data
Not Collected" remains truthful. This **corrects a stale plan-016 assumption**:
`watchOS/PrivacyInfo.xcprivacy` already exists (UserDefaults/CA92.1) — nothing
to create.

**Signing/account: not a blocker.** Paid membership is active (team
`CU54PVDRHC`); HealthKit is self-service on the App ID and automatic signing
handles the capability (#65). CI (`CODE_SIGNING_ALLOWED=NO`) is unaffected.

**App Store review obligations** (concrete, not hand-waved — details in the
[entitlements research](../docs/research/016-healthkit-watch-entitlements.md)):

- **2.5.1** — the App Store description must mention the Health integration.
- **5.1.1(i)/(ii)** — privacy policy link required; usage strings must be
  truthful and specific (the copy above states the concrete read/write;
  "Placar Beach Tennis" matches the existing pt-BR `CFBundleDisplayName`).
- **5.1.3(i)** — no advertising/data-mining use of health data.
- **5.1.3(ii)** — no false HealthKit data: the cancel-match path must discard
  or honestly end a partial workout, never pad it (§2 encodes this), and **no
  personal health info in iCloud** — a latent constraint now that
  `StoredMatch` gains workout fields (§3): if the store ever adopts CloudKit
  sync, those fields must be excluded or the sync reconsidered.

## 2. Session lifecycle against the real ScoreView hooks

New object: **`WorkoutManager.shared`** — a `@MainActor` singleton
`ObservableObject` at `watchOS/Services/WorkoutManager.swift`, injected as an
`@EnvironmentObject` beside `WatchSessionManager` (convention:
`WatchSessionManager.swift:5-7`). It owns the `HKHealthStore`, the
`HKWorkoutSession` + `HKLiveWorkoutBuilder`, the idempotence guard, and crash
recovery. Activity type: **`.tennis` for both `MatchType`s** — closest analog
for beach tennis, literal for tennis mode, one constant.

### Lifecycle table

| Event | Hook (`file:line`) | Session action |
|---|---|---|
| Match start (new) | `ScoreView.onAppear` — `ScoreView.swift:46-48` | If Health Monitoring is on (§3): first ever, request HealthKit authorization, then `startWorkout(.tennis)`. Idempotent — no-op if a session is already running (guard lives in the manager). |
| Match resume | Same `onAppear`, reached via `HomeView.swift:64-72` (`restoredState`) | Identical code path — why `onAppear` wins over `init`: one path covers new + resume, and SwiftUI `init` (where `matchStartDate` is set, `ScoreView.swift:30`) may run repeatedly and can't safely fire async side effects. Start lags `matchStartDate` by <1 s — negligible for HR/kcal. |
| App relaunch after crash/force-quit mid-match | `WorkoutManager` init | `HKHealthStore.recoverActiveWorkoutSession` — reattach if a session exists; the recovered session satisfies the idempotence guard, so the resumed match keeps its original workout. **Recovery is in v1.** |
| Match end | `.onChange(of: state.isMatchOver)` — `ScoreView.swift:49-53` | Snapshot accumulated stats synchronously from the live builder (avg HR bpm, active kcal) → pass into the existing `sendMatchResult` call (`ScoreView.swift:52`, feeding §3's payload fields) → then end + `finishWorkout` in a detached `Task`. The phone payload never waits on HealthKit's async finish; a HealthKit save failure can't lose the match result. |
| Match cancel | "End Match" in the Cancel alert — `ScoreView.swift:58-62` | Duration threshold, one if-statement: elapsed < ~2 min → `discardWorkout` (accidental start, no junk in Health); otherwise end + save — the exercise was real even if the match wasn't finished. (Also the 5.1.3(ii) honesty rule from §1.) |
| HealthKit denied | any | `startWorkout()` silently no-ops, this match and every later one — **scoring works unchanged. Hard requirement.** |

### Authorization and denial UX (#94)

- **Timing**: at first match start, as `ScoreView` appears — the prompt lands
  in context; app launch stays friction-free. Ask once; degrade silently.
- **No interstitial**: the bare system HealthKit sheet, no custom pre-prompt
  screen to build or localize.
- **Denial is fully silent on the watch, forever**: no hint, no Settings
  pointer, no passive indicator (no supported deep-link into Health
  permissions from a watch app; the watch app has no settings surface; deniers
  denied in context). The recovery path lives in the iPhone Settings footer
  (§3) plus App Store/support text.

### Live heart-rate readout in ScoreView (#93 — prototype variant B)

v1 surfaces one live metric during play: a compact **♥ bpm readout in the top
bar's right corner** (dead space mirroring the undo arrow), fed from
`WorkoutManager`'s live-builder stats. Heart rate **only** — no live calories:
there's no top-bar room without crowding, a dedicated strip squeezes the score
squares on 42/44 mm (worse in tennis mode with its extra sets row), and the
bottom bar costs the ✕ button its centered hit target. Calories stay
end-of-match data (§3). **Zero layout shift**: when no workout runs (denied,
toggled off, or metrics unavailable) the readout isn't rendered and
`ScoreView` renders exactly as today — the hard requirement holds for free.
All four explored variants live on the throwaway branch
[`prototype/016-live-metrics-scoreview`](https://github.com/renan002/beach-tennis-score/tree/prototype/016-live-metrics-scoreview)
(never merge; the build implements B properly, not by promoting prototype
code).

## 3. Workout data into Match History, and the Health Monitoring toggle

### Match History fields (#72) — capture **and** display in v1

**Exactly two optional fields**: `activeCalories: Double?` (kcal) and
`avgHeartRate: Double?` (bpm), added to both `MatchResultPayload` and
`StoredMatch`. `nil` is the single uniform absent state — HealthKit denied,
monitoring off, or a pre-feature match. Deliberately excluded: max HR, HR
time-series, total-vs-active energy (the Health app owns those views).

- **Wire change — the standard three places** (cross-reference plan 015's
  pattern): `WatchMessageKey` constants + encode/decode in
  `MatchResultPayload` (`Shared/WatchMessage.swift`), `StoredMatch` fields
  incl. `init(copying:)`, and display.
- **Migration**: optional-with-`nil`-default satisfies the #47
  property-default lightweight-migration rule (`StoredMatch.swift:10-13`). No
  custom migration stage. **Coordination**: if plan 015's name fields land
  too, both migrations go in one coordinated schema bump (one release adds
  all new fields together).
- **Display: iOS `MatchDetailView` only** — two rows alongside duration,
  hidden when `nil`. Not on the `MatchListView` row (clutter), not on watch
  `MatchHistoryView` (the watch's Health/Activity apps surface the workout
  natively). Denied-HealthKit matches render exactly like today's UI.
- **Why capture now**: the metrics only exist at match end; deferring capture
  would leave every earlier match permanently blank, while the cost today is
  two optional fields.

### Health Monitoring toggle in iPhone Settings (#95)

- **The toggle**: iPhone `SettingsView` gains a "Health" section with a single
  **Health Monitoring** toggle, default **on**. No watch-side mirror (the
  synced value persists on the watch; phone-away matches follow the last-known
  setting).
- **Sync**: `WatchSettings` gains `healthMonitoringEnabled: Bool` with
  missing-key decode default `true`, riding the existing full-replacement
  applicationContext push (`SettingsView.syncToWatchIfChanged` →
  `pushSettingsToWatch`).
- **Off gates the attempt**: the watch never calls `startWorkout()` and never
  requests authorization — a user who toggles off before their first match
  never sees the auth sheet, and `ScoreView` renders as today (same code path
  as "no workout running").
- **Denial awareness — watch reports status**: the iPhone *cannot* query the
  watch app's HealthKit grant (authorization is per-app; no API reads another
  app's status). So at every match start the watch checks
  `authorizationStatus` locally (synchronous, prompt-free,
  **toggle-independent** — avoids the deadlock where a forced-off toggle stops
  checking and a re-grant is never noticed), and **on change only** pushes
  granted/denied/undetermined via a **watch→phone `updateApplicationContext`**
  (the reverse direction of the settings channel, currently unused). The phone
  persists the last-known status.
- **Denied-state UI — display override, not overwrite**: while last-known
  status is *denied*, the toggle renders off + disabled with a footer hint
  pointing at iOS Settings; the persisted setting is untouched, so on
  re-grant tracking **auto-resumes** to the user's stored choice.
- **Copy** (String Catalog, keys = English): toggle label
  `Health Monitoring` / `Monitoramento de Saúde`; normal footer
  `The Watch records each match as a workout with live heart rate.` /
  `O Watch registra cada partida como um treino com frequência cardíaca em
  tempo real.`; denied footer
  `Health access was denied on the Watch. To re-enable it, open Settings ›
  Privacy & Security › Health.` / `O acesso à Saúde foi negado no Watch. Para
  reativar, abra Ajustes › Privacidade e Segurança › Saúde.`

## 4. Verdict, verification reality, and build outline

### Go/no-go: **GO**

Every risk the spike was chartered to retire is retired: the account can sign
with the capability (#65), the entitlement/plist delta is three `project.yml`
additions with no privacy-manifest work (#64), the lifecycle maps onto
existing hooks without touching `ScoreEngine` (#71), the schema change is
#47-safe (#72), and the Simulator covers nearly the whole development loop
(#66). No STOP condition triggered.

### Effort per surface

| Surface | Effort | Notes |
|---|---|---|
| Entitlements / plist (`project.yml` + `InfoPlist.strings`) | **S** | three additions, mechanical; `xcodegen generate` after |
| `WorkoutManager` object | **M** | session + builder lifecycle, idempotence guard, crash recovery, snapshot API; the risk core |
| `ScoreView` wiring + live HR readout | **S** | three hooks already exist; readout is one conditional top-bar element |
| Auth UX | **S** | bare system sheet; silence on denial means no UI to build on watch |
| Match History fields (wire + `StoredMatch` + detail rows) | **S** | mechanical three-place change ×2 fields, plus migration review burden |
| Settings toggle + status channel | **M** | new watch→phone applicationContext direction (send + receive/persist), denied-state UI logic |

Whole build: **M–L**, needing on-device verification before release.

### Verification reality — Simulator vs device

Per the [Simulator-reliability research](../docs/research/016-healthkit-simulator-reliability.md)
(§7 has the full split):

- **Sim-verifiable, every iteration**: authorization prompt + denial handling;
  session start/end state machine; builder callbacks updating the readout;
  `finishWorkout` producing a queryable `HKWorkout`; scoring/undo unaffected —
  the watchOS Simulator synthesizes live HR/kcal samples.
- **One-time sim smoke checks (watchOS 26 freshness)**: `didCollectDataOf`
  delivers heart rate + active energy within ~60 s; `isHealthDataAvailable()`
  is `true`.
- **Device-only (pre-release checklist)**: Activity-ring/Fitness credit and
  source attribution; realistic sensor values; `workout-processing`
  wrist-down survival over a full match; battery drain over ~45 min; behavior
  with the iPhone absent.
- **CI** (`xcodebuild test` on the iOS simulator scheme, per CLAUDE.md) proves
  only that it **compiles** — never that a workout records. This is why the
  feature was a spike first, and why the build plan must carry an explicit
  on-device protocol.

### Explicit non-goals

Out of scope for the build this design spawns: **no route/GPS**, **no
swimming/other sports** (`.tennis` covers both modes), **no retroactive
workouts** for matches scored before the feature ships, **no complications**
(plan 019's separate surface). Also deferred: live calories on the watch, max
HR / HR time-series in Match History, any watch-side settings surface.

### Build-plan outline (one plan, plans 006/007 executor style)

A single build plan — the entitlement is useless without the manager, the
manager without the wiring — with the device protocol as its last gate:

1. **Capabilities + strings** — the three `project.yml` additions from §1
   (entitlements block, `WKBackgroundModes`, both usage strings), pt-BR lines
   appended to `watchOS/pt-BR.lproj/InfoPlist.strings`, `xcodegen generate`.
   Verify: project generates; CI still green (compile gate).
2. **`WorkoutManager`** — new `watchOS/Services/WorkoutManager.swift`
   singleton per §2: `startWorkout(.tennis)` with auth-on-first-use and
   idempotence guard, `recoverActiveWorkoutSession` at init, synchronous
   stats snapshot, async end/finish, `discardWorkout` under the ~2-min
   threshold, published live heart rate. Verify in sim: session runs, denial
   no-ops, synthesized samples flow.
3. **`ScoreView` wiring + live readout** — start in `onAppear`, end in the
   `isMatchOver` `onChange` (snapshot → `sendMatchResult` → async finish),
   cancel threshold in the alert action; variant-B ♥ bpm readout in the top
   bar, absent when no workout runs. Verify: scoring/undo untouched with
   HealthKit denied (the review hot spot).
4. **Match History fields** — `activeCalories`/`avgHeartRate` through
   `MatchResultPayload` (three places, `?? nil` decode), `StoredMatch` incl.
   `init(copying:)`, two hidden-when-`nil` rows in `MatchDetailView`; payload
   round-trip + old-dictionary-fallback unit tests. Verify migration against
   a 1.3.x store; coordinate the bump with plan 015 if its fields land in the
   same release.
5. **Health Monitoring toggle + status channel** — `WatchSettings.
   healthMonitoringEnabled` (default `true`), Settings "Health" section with
   the §3 copy, gate in `WorkoutManager`; watch→phone auth-status
   applicationContext (send on change, receive + persist in
   `PhoneSessionManager`), denied-state toggle override. Unit-test the
   settings decode default and status-channel decode.
6. **On-device protocol + release collateral** — run the device-only
   checklist from the research doc §7 on a physical watch; update the App
   Store description (2.5.1) and confirm the privacy-policy link (5.1.1).

Steps 1–3 are shippable alone (workout + live HR, nothing stored); 4–5 are
additive. Step 6 gates the release, not the merge.
