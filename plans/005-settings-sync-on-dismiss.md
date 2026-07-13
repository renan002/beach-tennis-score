# Plan 005: Sync settings to the watch on any dismissal (and remove the dead push method)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5497f0b..HEAD -- BeachTennisCounter/iOS/Views/SettingsView.swift BeachTennisCounter/iOS/Services/PhoneSessionManager.swift CLAUDE.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. (Plans 003/004 touch
> `PhoneSessionManager.swift`'s delegate/insert code — changes there are
> expected; the `pushColorsToWatch`/`pushSettingsToWatch` pair at lines 31-49
> must still match the excerpt.)

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (soft: plan 001 for the build gate)
- **Category**: bug
- **Planned at**: commit `5497f0b`, 2026-07-12
- **Issue**: https://github.com/renan002/beach-tennis-score/issues/5

## Why this matters

`SettingsView` is presented as a sheet (`MatchListView.swift:46-47`). The push of colors/sport to the watch only happens inside the toolbar **Done** button's action — so a user who changes the modality or team colors and then swipes the sheet down never syncs the watch; it keeps stale settings until some future Done tap. Separately, `PhoneSessionManager.pushColorsToWatch()` is a byte-for-byte duplicate of `pushSettingsToWatch()` with **zero callers** — dead code that invites divergence.

## Current state

- `BeachTennisCounter/iOS/Views/MatchListView.swift:46-47` — presentation:

```swift
.sheet(isPresented: $showSettings) {
    SettingsView()
```

- `BeachTennisCounter/iOS/Views/SettingsView.swift:52-71` — sync gated on Done; originals captured in `onAppear`:

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button("Done") {
            let colorsChanged = phoneSession.teamAColorHex != originalColorA
                || phoneSession.teamBColorHex != originalColorB
            let sportChanged = sportSetting != originalSport
            if colorsChanged || sportChanged {
                phoneSession.sportSetting = sportSetting
                phoneSession.pushSettingsToWatch()
            }
            dismiss()
        }
    }
}
...
.onAppear {
    originalColorA = phoneSession.teamAColorHex
    originalColorB = phoneSession.teamBColorHex
    originalSport = sportSetting
}
```

Note: `phoneSession.sportSetting = sportSetting` is a functional no-op — both are `@AppStorage("sportSetting")` on the same `UserDefaults` key (`SettingsView.swift:14`, `PhoneSessionManager.swift:12`); the value is already shared the moment the Picker writes it.

- `BeachTennisCounter/iOS/Services/PhoneSessionManager.swift:31-49` — the identical twins:

```swift
func pushColorsToWatch() {
    guard WCSession.default.activationState == .activated,
          WCSession.default.isWatchAppInstalled else { return }
    try? WCSession.default.updateApplicationContext([
        WatchMessageKey.teamAColor: teamAColorHex,
        WatchMessageKey.teamBColor: teamBColorHex,
        WatchMessageKey.sportSetting: sportSetting
    ])
}

func pushSettingsToWatch() {  // identical body
```

`grep -rn "pushColorsToWatch" BeachTennisCounter --include='*.swift'` at `5497f0b` returns only the definition — no callers.

- `CLAUDE.md` "Data flow" section references `pushColorsToWatch()` by name — update it when the method is removed.
- Repo conventions: SwiftUI views keep logic in small `private func`s at the bottom of the struct (see `HomeView.handleNewMatch`, `SettingsView`'s computed vars).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Full test/build gate | see "Verified commands" in `plans/README.md` (from plan 001); the iOS target only compiles via the combined scheme, so use the test command (or CI) as the compile gate | `** TEST SUCCEEDED **` |
| Dead-reference check | `grep -rn "pushColorsToWatch" BeachTennisCounter --include='*.swift'` | no output |

## Scope

**In scope** (the only files you should modify):
- `BeachTennisCounter/iOS/Views/SettingsView.swift`
- `BeachTennisCounter/iOS/Services/PhoneSessionManager.swift` (delete `pushColorsToWatch` only)
- `CLAUDE.md` (rename the `pushColorsToWatch()` mention)

**Out of scope** (do NOT touch):
- `insertMatch`, the WCSession delegate methods, or anything else in `PhoneSessionManager.swift` (plans 003/004 own those areas).
- `WatchSessionManager.swift` — the watch receive side is fine.
- Adding `.interactiveDismissDisabled()` or blocking swipe-dismiss — the fix is to sync on dismiss, not to trap the user.

## Git workflow

- Branch: `advisor/005-settings-sync-on-dismiss`
- Commit style: `fix(settings): push watch settings on sheet dismissal, drop dead pushColorsToWatch`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Extract and re-wire the sync in SettingsView

In `SettingsView.swift`:

1. Add a private method at the bottom of the struct (near the other helpers):

```swift
private func syncToWatchIfChanged() {
    let colorsChanged = phoneSession.teamAColorHex != originalColorA
        || phoneSession.teamBColorHex != originalColorB
    let sportChanged = sportSetting != originalSport
    guard colorsChanged || sportChanged else { return }
    phoneSession.pushSettingsToWatch()
    // Refresh baselines so a later onDisappear doesn't double-push.
    originalColorA = phoneSession.teamAColorHex
    originalColorB = phoneSession.teamBColorHex
    originalSport = sportSetting
}
```

2. Replace the Done button's body with:

```swift
Button("Done") {
    syncToWatchIfChanged()
    dismiss()
}
```

(The `phoneSession.sportSetting = sportSetting` line is intentionally dropped — see the no-op note in "Current state".)

3. Add, next to the existing `.onAppear { ... }` modifier:

```swift
.onDisappear {
    syncToWatchIfChanged()
}
```

The baseline-refresh in step 1 makes the Done path and the onDisappear path idempotent (second call sees no diff and returns).

**Verify**: `grep -n "syncToWatchIfChanged\|onDisappear" BeachTennisCounter/iOS/Views/SettingsView.swift` → 1 definition + 2 call sites + 1 `.onDisappear`.

### Step 2: Delete the dead `pushColorsToWatch`

In `PhoneSessionManager.swift`, delete the entire `pushColorsToWatch()` function (lines 31-39 at `5497f0b`). Leave `pushSettingsToWatch()` untouched.

**Verify**: `grep -rn "pushColorsToWatch" BeachTennisCounter --include='*.swift'` → no output.

### Step 3: Update CLAUDE.md

In `CLAUDE.md`'s "Data flow" section, change the sentence naming `PhoneSessionManager.pushColorsToWatch()` to name `pushSettingsToWatch()` instead (same behavior described — `updateApplicationContext` with hex strings + sport).

**Verify**: `grep -n "pushColorsToWatch" CLAUDE.md` → no output; `grep -n "pushSettingsToWatch" CLAUDE.md` → ≥ 1 match.

### Step 4: Compile/test gate

Run the verified test command (this compiles the iOS target, which watch-only builds don't).

**Verify**: `** TEST SUCCEEDED **` (or, under plan 001's documented CI-only fallback, report that the gate is CI and confirm `build-for-testing` succeeds).

## Test plan

No new unit tests — the changed logic is SwiftUI lifecycle wiring with no seam in the current test target (no ViewInspector/UI-test infra exists in this repo; adding it is out of proportion for this fix). The compile/test gate plus this manual QA note for the operator: change Modality, swipe the sheet down (no Done), open the watch app → new sport takes effect.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -c "syncToWatchIfChanged" BeachTennisCounter/iOS/Views/SettingsView.swift` → 3 (one def, two calls)
- [ ] `grep -rn "pushColorsToWatch" BeachTennisCounter CLAUDE.md --include='*.swift' --include='*.md'` → no output
- [ ] Test command → `** TEST SUCCEEDED **`
- [ ] `git status` shows changes only to the 3 in-scope files
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `grep` finds a caller of `pushColorsToWatch` that didn't exist at `5497f0b` — re-scope before deleting.
- `SettingsView.swift`'s toolbar/onAppear structure no longer matches the excerpt.
- You are tempted to change how `sportSetting` is stored (e.g. moving it off `@AppStorage`) — that's a refactor beyond this fix.

## Maintenance notes

- `.onDisappear` also fires after Done-triggered dismissal — the baseline refresh inside `syncToWatchIfChanged` is what prevents a double `updateApplicationContext`; a reviewer should check that refresh survives edits. (A duplicate push would be harmless but wasteful — `updateApplicationContext` replaces the previous context.)
- If a settings item is ever added that the watch consumes, add it to `pushSettingsToWatch()` and to the change-detection in `syncToWatchIfChanged()` — both, or the new item hits the same stale-sync bug this plan fixes.
