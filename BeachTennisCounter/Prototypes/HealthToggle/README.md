# PROTOTYPE — #102 Health Monitoring toggle

Throwaway. Lives on `prototype/102-health-toggle` only. Never merge to `develop`.

Note: `origin/develop` already carries a working implementation of #102 (it
landed with PR #109). These prototypes exist to check that implementation's two
open questions before the issue is closed, not to build it from scratch.

## 1. Logic — does the display-override model hold?

**Question.** The Health section has two disagreeing inputs: the phone's stored
`healthMonitoringEnabled` and the watch's last-reported `HealthAuthStatus`. The
design calls for a *display override, not an overwrite*. Does that survive real
sequences — toggle off then deny, deny then re-grant, a fresh install that never
reported, a denial arriving while the row is already off?

```bash
BeachTennisCounter/Prototypes/HealthToggle/run.sh
```

`HealthToggleDisplay.swift` is the pure module (portable — this is the bit worth
lifting into `Shared/` if the model holds). `main.swift` is the throwaway TUI.

Keys: `t` tap toggle · `s` sync to watch (the Done button) · `g`/`d`/`u` watch
reports granted/denied/undetermined · `n` never reported · `r` reset · `q` quit.

The TUI tracks **stored** and **synced** separately on purpose — settings only
reach the watch on Done/dismiss, so "stored off but not yet synced ⇒ the watch
still starts a workout" is a reachable real state.

## 2. UI — what should the Health section look like?

**Question.** Three structurally different takes, mounted on the *real* iPhone
Settings screen (sub-shape A) so they're judged next to Sport/Teams/Appearance:

- **A — Bare row** — the shipped shape: one Toggle + a footer sentence.
- **B — Explained** — a card that states what gets recorded before asking.
- **C — Status-first** — leads with the watch's live Health state; toggle secondary.

Run the iOS app from Xcode (or `/verify`) and open Settings. The floating black
bar at the bottom cycles variants and fakes the watch's reported auth status, so
the denied override is judgeable without a real watch.

Code: `iOS/Views/SettingsHealthSectionPrototype.swift`, mounted by two clearly
marked hunks in `iOS/Views/SettingsView.swift`.

## Verdict

_(fill in — which variant won, and whether the display-override model held)_
