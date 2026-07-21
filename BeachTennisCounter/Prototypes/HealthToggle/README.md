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

**UI: variant B — Explained wins.** Driven in the iPhone 17 Simulator on
2026-07-21 against the real Settings screen. Screenshots of all three variants
in both the granted and denied states are in `screenshots/`.

B's card states what the watch actually records — live heart rate, active
calories into Match History, the match saved as a workout — before asking for
the toggle. The bare row (A) asks for a health permission with one sentence of
justification; the status-first layout (C) puts the watch's grant state above
the user's own choice, which reads as a diagnostic panel rather than a setting.
When denied, B degrades cleanly: the bullet list disappears and the card
collapses to icon + title + denied footer with the toggle off and dimmed.

**Folding B in requires new String Catalog keys.** The three bullet strings and
B's inline description are English literals in the prototype and rendered
untranslated next to pt-BR copy. Per CLAUDE.md they must be keyed in the same
commit that lands the copy.

**Logic: the display-override model held.** No sequence broke it — a denial
never writes the stored value, so re-granting auto-resumes the user's choice.
Two things the TUI surfaced, both correct-by-design but worth knowing:

1. **Stored ≠ synced.** Settings only reach the watch on Done/dismiss, so
   toggling off and killing the app before dismissing leaves the watch on the
   old value and it still starts a workout at the next Match.
2. **The shipped model has no "never reported" state.** `PhoneSessionManager`
   defaults `watchHealthAuthStatus` to `.undetermined`, so the prototype's
   `nil` case collapses onto `.undetermined`. Both render the normal footer,
   so nothing is lost — the model is simpler than the prototype assumed.
