# Plan 009: Wire MARKETING_VERSION into both Info.plists

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5497f0b..HEAD -- BeachTennisCounter/project.yml BeachTennisCounter/iOS/Info.plist BeachTennisCounter/watchOS/Info.plist`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `5497f0b`, 2026-07-12
- **Issue**: https://github.com/renan002/beach-tennis-score/issues/9

## Why this matters

`project.yml` defines `MARKETING_VERSION: "0.1.2"` and
`CURRENT_PROJECT_VERSION: "3"`, but both committed Info.plists hardcode
`CFBundleShortVersionString` = `1.0` and `CFBundleVersion` = `1` and never
reference those build settings. Because the targets use `INFOPLIST_FILE`, the
built apps report **version 1.0 (1)** — the versions in `project.yml` are dead
config. This bites twice: the Settings screen shows the wrong version
(`SettingsView.swift:90-92` reads `CFBundleShortVersionString`), and any App
Store submission versioning done via `project.yml` silently does nothing.

## Current state

- `BeachTennisCounter/project.yml:15-19` — the intended source of truth:

```yaml
settings:
  base:
    SWIFT_VERSION: "6.0"
    MARKETING_VERSION: "0.1.2"
    CURRENT_PROJECT_VERSION: "3"
```

- `BeachTennisCounter/iOS/Info.plist:19-22` and
  `BeachTennisCounter/watchOS/Info.plist:19-22` — identical hardcoded values
  in both files:

```xml
<key>CFBundleShortVersionString</key>
<string>1.0</string>
<key>CFBundleVersion</key>
<string>1</string>
```

- Both targets declare an `info:` block in `project.yml` (iOS at lines 41-49,
  watch at lines 71-77) with a `properties:` map — XcodeGen regenerates the
  plist at `info.path` on every `xcodegen generate`, merging defaults with the
  given properties. Keys absent from `properties` get XcodeGen defaults —
  which is exactly where the hardcoded `1.0`/`1` come from.
- App Store constraint worth knowing: a watchOS companion app's
  `CFBundleShortVersionString` must match its iOS host's. Using the same
  `$(MARKETING_VERSION)` variable in both targets satisfies this by
  construction.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Regenerate project + plists | `cd BeachTennisCounter && xcodegen generate` | `Generated project at .../BeachTennisCounter.xcodeproj` |
| Watch-only build gate | `cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build` | `** BUILD SUCCEEDED **` |
| Wiring check | `grep -n "MARKETING_VERSION" BeachTennisCounter/iOS/Info.plist BeachTennisCounter/watchOS/Info.plist` | 1 match per file |

## Scope

**In scope** (the only files you should modify):
- `BeachTennisCounter/project.yml`
- `BeachTennisCounter/iOS/Info.plist` (via `xcodegen generate`; hand-edit only per Step 2's fallback)
- `BeachTennisCounter/watchOS/Info.plist` (same)
- `BeachTennisCounter/BeachTennisCounter.xcodeproj/*` (regenerated — do not hand-edit)

**Out of scope** (do NOT touch):
- The version *values* themselves — keep `0.1.2` / `3`; this plan wires
  plumbing, it does not bump versions.
- `SettingsView.swift` — its `appVersion` read is correct; it will show
  `0.1.2` automatically once the plumbing works.
- Any other key in the Info.plists or any other setting in `project.yml`.

## Git workflow

- Branch: `advisor/009-wire-marketing-version`
- Commit style: `chore(build): wire MARKETING_VERSION/CURRENT_PROJECT_VERSION into Info.plists`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add the version keys to both `info.properties` blocks

In `BeachTennisCounter/project.yml`, add these two lines to the
`info.properties` map of **both** the `BeachTennisCounter` target (under line
43's `properties:`) and the `BeachTennisCounterWatch` target (under line 73's
`properties:`):

```yaml
        CFBundleShortVersionString: "$(MARKETING_VERSION)"
        CFBundleVersion: "$(CURRENT_PROJECT_VERSION)"
```

(Match the indentation of the sibling keys, e.g. `CFBundleName`.)

**Verify**: `grep -c 'CFBundleShortVersionString: "$(MARKETING_VERSION)"' BeachTennisCounter/project.yml` → `2`.

### Step 2: Regenerate and confirm the plists picked it up

Run `cd BeachTennisCounter && xcodegen generate`, then check both plists.

**Verify**: `grep -A1 "CFBundleShortVersionString" BeachTennisCounter/iOS/Info.plist BeachTennisCounter/watchOS/Info.plist` → each shows `<string>$(MARKETING_VERSION)</string>`.

**Fallback** (only if the generate step left the plists unchanged — i.e. this
XcodeGen version does not rewrite existing plists): hand-edit both
`Info.plist` files, replacing `<string>1.0</string>` with
`<string>$(MARKETING_VERSION)</string>` and `<string>1</string>` (the
`CFBundleVersion` value at lines 21-22 only) with
`<string>$(CURRENT_PROJECT_VERSION)</string>`, then re-run the Verify grep.
Keep the Step 1 `project.yml` change either way so future regenerations stay
consistent.

### Step 3: Build gate and runtime check

Run the watch-only build, then confirm the built product resolved the
variables:

```bash
cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build
plutil -p build/Debug-watchsimulator/BeachTennisCounterWatch.app/Info.plist | grep -E "CFBundleShortVersionString|CFBundleVersion"
```

**Verify**: build → `** BUILD SUCCEEDED **`; plutil output shows
`CFBundleShortVersionString" => "0.1.2"` and `"CFBundleVersion" => "3"`
(resolved values, not the `$(...)` literals).

## Test plan

No unit tests — build-configuration change. The gates are Step 2's grep
(source plists reference the variables) and Step 3's `plutil` check (the
built product resolves them to `0.1.2`/`3`).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -c "MARKETING_VERSION" BeachTennisCounter/project.yml` → ≥ 3 (the setting + 2 references)
- [ ] Both source Info.plists contain `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)`
- [ ] Built watch app's Info.plist shows `0.1.2` / `3` (Step 3 plutil check)
- [ ] `git status` shows changes only to in-scope files
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The built plist in Step 3 shows the literal string `$(MARKETING_VERSION)`
  unresolved — the target isn't substituting variables in that key; report
  rather than switching to `GENERATE_INFOPLIST_FILE` or other build-setting
  surgery.
- `xcodegen generate` rewrites the plists but *drops* other existing keys
  (compare `git diff` of the plists — only the two version entries should
  change). If unrelated keys vanish, restore and use the Step 2 fallback.

## Maintenance notes

- Future version bumps happen in exactly one place: `MARKETING_VERSION` /
  `CURRENT_PROJECT_VERSION` in `project.yml` (then `xcodegen generate`).
- Reviewer should scrutinize the plist diff: only the two version values
  should change in each file.
- App Store validation requires the watch and iOS
  `CFBundleShortVersionString` to match — both now derive from the same
  variable; don't ever override it per-target.
