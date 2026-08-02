# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

All commands run from inside `BeachTennisCounter/`.

**Regenerate `.xcodeproj` after any structural change** (new files, new targets, changed settings):
```bash
cd BeachTennisCounter && xcodegen generate
```

**Build watchOS target from CLI:**
```bash
xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator
```

**Run unit tests from CLI:**
```bash
xcodebuild test -project BeachTennisCounter.xcodeproj -scheme BeachTennisCounter -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```
Substitute any available device from `xcrun simctl list devices available` if `iPhone 17` is absent. The same tests run in CI on every push/PR (`.github/workflows/ci.yml`), which is the authoritative gate.

**Combined iOS + watchOS build:** Use Xcode.app, or a scheme build with an explicit destination:
```bash
xcodebuild -project BeachTennisCounter.xcodeproj -scheme BeachTennisCounter -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Building the iOS *target* with `-sdk iphonesimulator` fails instead — it drags the watch target along under the iOS SDK, which its asset catalog rejects (`app icon set … did not have any applicable content`). Build each target with its own SDK, or go through a scheme.

> After adding or removing any `.swift` file, always run `xcodegen generate` — the `.xcodeproj` won't pick up the new file automatically.

### Build configurations

Three: `Debug`, `Dev`, `Release` — `Dev` is a debug variant that installs alongside the App Store app.

| | Debug / Release | Dev |
|---|---|---|
| iOS bundle id | `com.renan.beachtennis` | `com.renan.beachtennis.dev` |
| Display name | Beach Tennis Score | Beach Dev |
| App Group | `group.com.renan.beachtennis` | `group.com.renan.beachtennis.dev` |
| App icon | `AppIcon` | `AppIcon-Dev` |
| `DEV` marker in Settings | absent | present |

The table is the **flavor** axis — `Dev` against the other two. Not everything per-configuration splits that way: `PRO_ON_SALE` splits `Release` against `Debug` + `Dev` (see "Pro is dark in Release" below), so it gets no row here. A new configuration has to be considered against both axes; copying a row is not enough.

Everything flavored derives from three settings in `project.yml` — `BUNDLE_ID_SUFFIX`, `APP_DISPLAY_NAME`, `APPICON_SUFFIX` — set per configuration in one place. Don't hardcode a flavored value anywhere else; the App Group in particular is read at runtime from the `AppGroupIdentifier` Info.plist key, which derives from the bundle id.

`APP_DISPLAY_NAME` alone does **not** name the app. A localized `InfoPlist.strings` outranks `CFBundleDisplayName`, and `.strings` files get no build-setting expansion — so `scripts/flavor-localized-app-name.sh` rewrites the name in the built product as a post-build phase on both app targets. Verify a name change by reading the home screen on a pt-BR device, not `Info.plist`.

CI gates the flavoring with `scripts/validate-bundle-ids.sh`, which asserts that all three configurations still resolve to the fixed bundle ids and that `PRODUCT_BUNDLE_IDENTIFIER` is still `BASE_BUNDLE_ID + BUNDLE_ID_SUFFIX` — the latter is what proves the entitlement's `group.$(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)` and the plist's `group.$(PRODUCT_BUNDLE_IDENTIFIER)` name the same App Group. The unit suite cannot catch this: its one configuration-sensitive test asserts the group *tracks* the bundle id, which stays true when the bundle id is wrong. `scripts/test-validate-bundle-ids.sh` tests the validator against generated fixture projects; run it locally, CI does not.

`DEVELOPMENT_TEAM` and `CODE_SIGN_STYLE` live in `project.yml` because picking a team in Xcode's Signing & Capabilities tab writes it into the `.xcodeproj`, which `xcodegen generate` then discards.

Schemes **Beach Dev** and **Beach Dev Watch** run that configuration; the original schemes stay on `Debug`, so the production bundle id remains debuggable. Neither Dev scheme has an archive action — the dev flavor is a local Xcode install, not a distribution.

XcodeGen matches `settings.configs` keys by case-insensitive **substring** unless the key is an exact config name. `Dev` is exact and safe; a config named `Development` would silently inherit every Dev setting.

### Dev-flavor guardrails

The `DEV` marker rides on the Settings version footer (`Versão 1.3.1 · DEV`), gated by `#if DEV_FLAVOR` — a compilation condition set only on the `Dev` configuration, so the string is physically absent from Debug and Release binaries. Settings is the **only** place it may appear: never the scoring screens, and never the Cartão de Resultado, which is an image made to be posted publicly. It is composed into the interpolated value rather than the copy, so the `Version %@` catalog key stays untouched and `DEV` reads the same in every locale.

`scripts/validate-release-version.sh` refuses to cut a release whose bundle id carries a suffix. It resolves `BASE_BUNDLE_ID` + `BUNDLE_ID_SUFFIX` out of the **Release** configuration of the checked-in `project.pbxproj` — not `project.yml`, because the pbxproj is what Xcode archives — and fails loudly if it can no longer find what it walks, rather than silently vouching for nothing. `scripts/test-validate-release-version.sh` covers it and runs in CI on ubuntu; every one of its bundle-id cases fails if the guard is deleted.

### Pro is dark in Release

Pro is fully built but **not on sale** in shipped builds: the purchase surface and all three Pro gates sit behind `FeatureFlags.proOnSale`, backed by the `PRO_ON_SALE` compilation condition — defined on `Debug` and `Dev`, **absent** from `Release`. A dark build has no purchase affordance, makes no App Store traffic, and leaves every Pro feature free, which is exactly the pre-Pro behaviour. See ADR 0008; the flip procedure is `docs/pro-switch-on-checklist.md`.

Rules that keep this working, all of them easy to break by accident:

- `iOS/FeatureFlags.swift` holds the mechanism's **only** `#if`. Every consumer branches on a plain `Bool`, so the off state — the one that ships and that nobody runs locally — stays compiled and testable. Don't spell `PRO_ON_SALE` anywhere but `project.yml` and that file.
- **Gates read `isPro`, never `FeatureFlags`.** `ProEntitlement` splits into `ownsPro` (StoreKit's answer, read only by the purchase surface) and `isPro = ownsPro || !proOnSale` (what the app may do, read by every gate). The flag has exactly three consumers; a fourth is a smell.
- Setting `SWIFT_ACTIVE_COMPILATION_CONDITIONS` **replaces** XcodeGen's automatic value on a debug-type config, so `DEBUG` is restated on `Debug` and `Dev`. Drop it and `#if DEBUG` silently goes dark project-wide.

CI gates it with `scripts/validate-release-is-dark.sh` in its own unconditional ubuntu job, **`release-is-dark`** — the check to require on `main`, since that merge is what triggers the build. It asserts that no configuration named `Release` defines `PRO_ON_SALE`, walking every configuration block, and fails loudly if it cannot find what it walks. `scripts/test-validate-release-is-dark.sh` covers it and runs in the same job. There is no bypass: the guard is deleted together with its test and its job in the same diff that flips the flag.

### Where builds actually come from

**Nothing in this repository archives or uploads a binary.** Distribution builds are produced by **Xcode Cloud**, triggered by a merge to `main`; its workflow — scheme, configuration, environment, custom build settings — lives entirely in App Store Connect, with no `ci_scripts/` and no trace here. GitHub Actions runs tests and the guard scripts, and that is all it does. So `project.yml` telling you `Release` is dark does not by itself tell you the *shipped* binary is dark — which configuration gets archived is not readable from inside this repo.

## Architecture

The project has two targets sharing a `Shared/` layer:

```
Shared/          ← compiled into both targets
  MatchState.swift    — all data models (Team, PointScore, GameRecord, MatchState)
  ScoreEngine.swift   — pure scoring logic, no UI imports
  MatchInProgress.swift — the Match being scored: state, Undo Stack, effect ordering
  WatchMessage.swift  — WatchConnectivity payload constants and MatchResultPayload
  Localizable.xcstrings — pt-BR String Catalog; the only strings table in the project

watchOS/         ← Apple Watch app (primary runtime UI)
  BeachTennisWatchApp.swift
  Views/          HomeView → ServeSelectionView → ScoreView → MatchHistoryView
  Services/WatchSessionManager.swift   — @MainActor singleton, WCSession delegate

iOS/             ← iPhone companion (history + settings)
  BeachTennisApp.swift
  Models/StoredMatch.swift             — @Model (SwiftData)
  Views/          MatchListView → MatchDetailView, SettingsView
  Services/PhoneSessionManager.swift   — @MainActor singleton, WCSession delegate
  Services/ProEntitlement.swift        — @MainActor singleton, StoreKit 2 (iOS only)
```

### Data flow

- **Scoring:** `ScoreView` holds a `MatchInProgress`, which owns the `MatchState` and the Undo Stack and is the only caller of `ScoreEngine` — no mutation outside `ScoreEngine`. Every interaction (`start`, `awardPoint`, `undo`, `cancel`) returns an ordered `[MatchInProgress.Effect]`; the screen's `perform(_:)` carries them out synchronously and decides nothing. That is what makes the ordering testable: the watch target is reachable by no test in this project, so anything sequenced inline in the screen is untestable by construction. Ordering that matters lives in the module and is pinned by `MatchInProgressTests` — above all the terminal one, where `.sendResult` precedes `.endWorkout` because the screen snapshots the workout stats as it performs the send.
- **Watch → iPhone:** At match end `WatchSessionManager.sendMatchResult(_:duration:)` calls `WCSession.transferUserInfo`. `PhoneSessionManager.session(_:didReceiveUserInfo:)` decodes via `MatchResultPayload.from(_:)` and inserts a `StoredMatch` into SwiftData.
- **iPhone → Watch (settings):** `PhoneSessionManager.pushSettingsToWatch()` builds a `WatchSettings` and calls `WCSession.updateApplicationContext(settings.toApplicationContext())`. Both watch receive paths (`activationDidCompleteWith` reading `receivedApplicationContext`, and `didReceiveApplicationContext`) decode via `WatchSettings.from(_:)` and apply the value. `WatchSettings` is the settings-path counterpart to `MatchResultPayload`: it owns the dictionary encode/decode, so a new watch-consumed setting is added in one place. The context is a full replacement — a missing key decodes to the type's default rather than leaving a stale value applied. Decode the `Sendable` `WatchSettings` in the `nonisolated` callback *before* any `Task { @MainActor in }`, per the Swift 6 `Sendable` rules.

### Pro unlock (StoreKit)

`ProEntitlement` is the only place StoreKit is touched: one non-consumable
(`com.renan.beachtennis.pro`), `isPro` recomputed from
`Transaction.currentEntitlements` at launch and on every `Transaction.updates`
event. There is no persisted flag of our own and no receipt server — StoreKit is
the source of truth, so any gate is a plain `isPro ? … : …` reading the injected
observable. Keep it in `iOS/`: `Shared/` compiles into the watch target, which
links no StoreKit and shows no purchase UI (ADR 0004). `ProEntitlementTests`
enforces both that rule and the product id.

`Pro.storekit` is the local StoreKit configuration; the `BeachTennisCounter` and
`Beach Dev` schemes point their run action at it, so a purchase can be demoed in
the simulator with no App Store Connect record. It only applies to runs launched
from Xcode — an app installed with `simctl` sees no products, and the purchase
sheet correctly reports Pro as unavailable.

### Beach Tennis scoring rules (encoded in ScoreEngine)

- Match = first to 6 games (the UI calls them "sets")
- Points per game: 0 → 15 → 30 → 40 → win; at 40-40 → golden point (sudden death)
- At 5-5 games: first to 7 wins (no tiebreak, normal scoring continues)
- At 6-6 games: super tiebreak to 7 points, win by 2; serve rotation `block = (pointsPlayed-1)/2; block%2==0 → other team serves`

### Swift 6 concurrency notes

- `MatchState` and `GameRecord` are `Sendable` structs; `Team` and `PointScore` are `Sendable` enums.
- WCSession delegate callbacks are `nonisolated`; always extract `Sendable` primitives (e.g. `String`) before crossing into `Task { @MainActor in }`.
- Both session managers are `@MainActor` singletons injected as `@EnvironmentObject`.

### Platform split for Color helpers

- **Shared:** `HexColor.components(_:)` is the only place a hex string is parsed — Foundation only, no `Color`, so the parsing is testable. The watch layer is reachable by no test, so a decode written there is a decode nobody can assert on; that is why the parsing moved and the `Color` wrappers stayed.
- **iOS only:** `Color.toHex()` uses `UIColor` — lives in `PhoneSessionManager.swift`.
- **watchOS only:** `Color(hex:)` decode-only — lives in `WatchSessionManager.swift`. No `toHex()` on watch.

Both `Color(hex:)` initializers wrap `HexColor` and keep **different failure conventions on purpose**: the watch's is failable because it decodes colours synced from the phone, which can arrive garbled, and its two call sites fall back to red and blue; the phone's is non-failable, falling back to black, because it decodes its own literals and its own stored values. Don't unify them — the duplication is two lines and the divergence is the point.

## Localization

`Shared/Localizable.xcstrings` is the single strings table for both targets (pt-BR;
English is the source language, so it needs no entries). Per-target `.lproj/Localizable.strings`
files must not come back — a String Catalog cannot co-exist with a same-named `.strings`
table and the build fails outright. `InfoPlist.strings` is separate and still per-target.

- Keys are the English source strings. Reword UI copy and you must re-key the catalog in
  the same commit, or the entry silently falls back to the new English.
- A missing entry is never a crash — it renders the key. So universal tennis vocabulary
  (`Sets`, `Games`, `TB`, `Ad`, `Beach Tennis`, `Beach`) deliberately has no entries.
- `Game %lld` maps to `Set %lld` on purpose: the beach UI calls games "Sets".
- `Text("…")`/`Button("…")` localize automatically via `LocalizedStringKey`. Plain `String`
  does not — computed vars and ternaries of string literals need `String(localized:)`.
- Never translate `Picker` tag values or `UserDefaults`-persisted strings
  (`beachTennis`, `tennis`, `multiple`) — they are storage keys, not display text.

## Git workflow

### Branches

- New feature branches are always cut from `develop`, never from `main` or another feature branch.
- **`git fetch origin` before cutting, and cut from `origin/develop`.** The local
  `develop` ref only moves when you pull it, so in a worktree it is routinely many
  commits stale — reading it without fetching will tell you that work already merged
  is missing, and you will branch from the wrong base.
- Create the branch before writing any code for that feature — don't develop first and branch later.
- Name branches `<type>/<short-description>`, e.g. `feat/serve-rotation-fix`, `bug/watch-sync-crash`, matching the commit `<type>` below.

### Commits

Use Conventional Commits: `<type>(<optional scope>): <description>`.

Types: `feat` (new feature), `fix` (bug fix), `chore` (tooling/maintenance, no source behavior change), `docs` (documentation only), `refactor` (code change that neither fixes a bug nor adds a feature), `test` (adding/correcting tests), `ci` (CI/CD config).

### Pull requests

- PRs target `develop`, not `main`.
- PR title matches the title of the GitHub issue the PR resolves.
- PR body follows `.github/PULL_REQUEST_TEMPLATE.md`.

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues (renan002/beach-tennis-score), via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default canonical labels: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
