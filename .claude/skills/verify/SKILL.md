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
