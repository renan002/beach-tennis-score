---
name: verify
description: Build, launch, and drive the iOS app in the simulator to verify a change end-to-end. Use when a change to iOS/watchOS product code needs runtime observation, screenshots, or manual driving beyond the unit tests.
---

# Verifying in the iOS Simulator

All commands from `BeachTennisCounter/`. Pick an iPhone 17 device UDID from
`xcrun simctl list devices available` (there are usually two OS versions; use
the newest) and target it by UDID everywhere — `booted` is ambiguous because
the user often has an iPhone+Watch pair booted too.

```bash
xcrun simctl boot <UDID>
xcodebuild -project BeachTennisCounter.xcodeproj -scheme BeachTennisCounter \
  -destination 'platform=iOS Simulator,id=<UDID>' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
xcrun simctl install <UDID> build/Build/Products/Debug-iphonesimulator/BeachTennisCounter.app
xcrun simctl launch <UDID> com.renan.beachtennis
xcrun simctl io <UDID> screenshot out.png
```

- The simulator is set to pt-BR — screenshots double as localization checks.
- App data container: `xcrun simctl get_app_container <UDID> com.renan.beachtennis data`,
  live store at `<container>/Library/Application Support/default.store`.
  The container path changes on reinstall — re-derive it after every install.
- To seed matches, copy the empty `default.store` and INSERT into `ZSTOREDMATCH`
  with sqlite3 (set `Z_ENT=1`, `Z_OPT=1`, `ZID=randomblob(16)`, dates are
  seconds since 2001-01-01), bump `Z_MAX` in `Z_PRIMARYKEY`, then
  `PRAGMA wal_checkpoint(TRUNCATE)`.

## Tapping (no idb/cliclick installed)

Synthesize clicks with pyobjc Quartz (`CGEventPost`), after
`osascript -e 'tell application "Simulator" to activate'`. Get the window
frame from `CGWindowListCopyWindowInfo` (owner `Simulator`, window name =
device name). Map screenshot pixel `(ox, oy)` (1206×2622 for iPhone 17) to
screen points with `x = winX + ox*0.3275`, `y = winY + 28 + oy*0.3275`.

Gotchas, learned the hard way:
- Clicks in the top ~110 screenshot-pixels (nav-bar buttons like the gear)
  are swallowed by the window chrome — reach those screens another way
  (e.g. a tappable row further down).
- Confirmation-dialog/popover buttons sometimes ignore synthetic clicks
  entirely; don't grind on them, verify that path in unit tests instead.
- A click that "does nothing" usually means the Simulator lost frontmost
  status — re-activate and re-read the window frame first.

## Verifying the watchOS app (paired iPhone + Watch)

The watch app is the product's primary UI, so most runtime checks live here.
CLAUDE.md says the *combined* CLI build is blocked, but building each target
**separately** against its own destination works fine.

```bash
# Find the active pair; boot both (the watch is often already booted).
xcrun simctl list pairs | grep -A2 active     # -> phone + watch UDIDs
xcrun simctl boot <phoneUDID>; xcrun simctl boot <watchUDID>

xcodebuild -project BeachTennisCounter.xcodeproj -scheme BeachTennisCounterWatch \
  -destination 'platform=watchOS Simulator,id=<watchUDID>' -derivedDataPath build build
xcrun simctl install <watchUDID> build/Build/Products/Debug-watchsimulator/BeachTennisCounterWatch.app
xcrun simctl launch <watchUDID> com.renan.beachtennis.watchkitapp
xcrun simctl io <watchUDID> screenshot watch.png
```

Bundle ids: phone `com.renan.beachtennis`, watch `com.renan.beachtennis.watchkitapp`.

**Watch tap calibration** (same Quartz `CGEventPost` flow as the iPhone). The
watch screenshot is **416×496**. Read the Simulator window whose name contains
`46mm`, then `scale = winW/416` (~0.66), `titleOffset = winH − 496*scale` (~49),
`screen_x = winX + ox*scale`, `screen_y = winY + titleOffset + oy*scale`.
Synthetic taps drop ~40% when sent fast — send extras and screenshot to confirm
each step; don't trust a blind count.

**Match flow that fires a watch→phone result send:** tap `+` (Nova Partida) →
sport picker (Beach Tennis) → serve picker (Time A) → score view. In the score
view the Team A red square center is ~(115,285), Team B blue ~(300,285); ~24
taps on A wins 6–0 (no deuce) and calls `sendMatchResult`. Verify persistence on
the phone: `xcrun simctl get_app_container <phoneUDID> com.renan.beachtennis data`
then sqlite3 on `<container>/Library/Application Support/default.store`.

### Entitlement-gated features (HealthKit, etc.)

`CODE_SIGNING_ALLOWED=NO` **strips entitlements** — the app runs but every
HealthKit call fails with `Code=4 "Missing com.apple.developer.healthkit
entitlement"` and the feature silently no-ops. To exercise such a feature, build
**without** that flag: plain `xcodebuild … build` ad-hoc-signs (`--sign -`) and
embeds the generated `*-Simulated.xcent` into the binary's `__entitlements`
section, which is what the simulator actually reads. (`codesign -d --entitlements`
shows an *empty* dict on the bundle signature — that's normal; the real grant is
in the linked section, confirmable via the `*-Simulated.xcent` file.)

Read HealthKit runtime behavior from the watch's log:
`xcrun simctl spawn <watchUDID> log show --last 60s --predicate 'senderImagePath CONTAINS[c] "HealthKit"'`
— look for `Initializing workout session`, `Running(2)`, `Missing … entitlement`.

**System privacy sheets can't be driven synthetically.** The HealthKit
authorization sheet ("Acesso ao App Saúde" / "Health Access") runs out-of-process
and ignores `CGEventPost` taps — you can confirm it *appears* (in-context, right
copy/locale) but cannot grant it via automation. To finish an end-to-end check
that needs the grant, ask the user to click through it in the Simulator window
(Revisar → toggle categories → Concluir), then resume driving.
