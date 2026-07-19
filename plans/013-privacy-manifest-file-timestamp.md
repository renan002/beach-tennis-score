# Plan 013: Declare the File Timestamp required-reason API in the iOS privacy manifest

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9d05103..HEAD -- BeachTennisCounter/iOS/PrivacyInfo.xcprivacy BeachTennisCounter/iOS/Services/StoreRecovery.swift`
> If either in-scope/referenced file changed since this plan was written,
> compare the "Current state" excerpts against the live code before
> proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: migration (App Store compliance)
- **Planned at**: commit `9d05103`, 2026-07-17

## Why this matters

Apple requires every app to declare a reason for each "required reason API" it
calls, in a `PrivacyInfo.xcprivacy` manifest. `StoreRecovery` (the store
quarantine/restore feature, iOS-only) reads **file creation dates** in two
places, which is a File Timestamp required-reason API. The iOS privacy manifest
currently declares only the UserDefaults category, so the File Timestamp use is
**undeclared**. App Store Connect flags this at upload as warning
**ITMS-91053 ("Missing API declaration")**, and under Apple's enforcement this
can escalate from a warning to a hard rejection. The fix is a few lines of
plist and makes the manifest honestly describe what the binary does — no
behavior change.

Only the **iOS** manifest needs this. `StoreRecovery.swift` lives under `iOS/`
and is compiled into the iOS app target only (see `project.yml`: the watch
target's `sources` are `watchOS` + `Shared`, not `iOS`), so the watch binary
does not call these APIs and its manifest must stay as-is.

## Current state

- `BeachTennisCounter/iOS/Services/StoreRecovery.swift` calls File Timestamp
  APIs in exactly two places, both reading the creation date of files inside
  the app's App Group container (`group.com.renan.beachtennis/Library/Application
  Support`, per `LiveStore.directory`):
  - Line 155 — `includingPropertiesForKeys: [.creationDateKey]` (listing
    quarantine folders to sort by recency in `pruneOldQuarantines`).
  - Line 182 — `(try? fileManager.attributesOfItem(atPath: dir.path))?[.creationDate]`
    (fallback recency when a quarantine has no readable manifest, in
    `quarantineDate(of:)`).
- `BeachTennisCounter/iOS/PrivacyInfo.xcprivacy` — the iOS manifest as it exists
  today (this is the whole file):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

- The correct declaration to add is the **File Timestamp** category with reason
  code **`C617.1`** — Apple's documented reason for *"accessing the timestamps …
  of files inside the app container, app group container, or the app's CloudKit
  container."* That is exactly this usage (creation dates of quarantine folders
  in the App Group container). Reference: Apple, "Describing use of required
  reason API" — File timestamp APIs section.
- Convention: the existing UserDefaults entry pairs the category constant with a
  reason-codes array. The new entry follows the identical shape.
- Build convention (`CLAUDE.md`): `.xcprivacy` is a resource already bundled by
  the iOS target because it sits under the `iOS/` source path. **Editing its
  contents does not require `xcodegen generate`** — no files are added or
  removed. Do not run xcodegen for this plan.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Validate plist syntax | `plutil -lint BeachTennisCounter/iOS/PrivacyInfo.xcprivacy` | `...: OK` |
| Confirm category added | `grep -c NSPrivacyAccessedAPICategoryFileTimestamp BeachTennisCounter/iOS/PrivacyInfo.xcprivacy` | `1` |
| Confirm watch manifest untouched | `grep -c FileTimestamp BeachTennisCounter/watchOS/PrivacyInfo.xcprivacy` | `0` |

## Scope

**In scope** (the only file you should modify):
- `BeachTennisCounter/iOS/PrivacyInfo.xcprivacy`

**Out of scope** (do NOT touch):
- `BeachTennisCounter/watchOS/PrivacyInfo.xcprivacy` — the watch target does not
  compile `StoreRecovery`, so it must not gain a File Timestamp entry.
- `StoreRecovery.swift` — do not change the code to avoid the API; the timestamp
  read is legitimate app functionality. This plan declares it, not removes it.
- Any other `NSPrivacy*` key (tracking, collected data types) — no change.
- `project.yml` / the `.xcodeproj` — no regeneration.

## Git workflow

- Branch: `chore/013-privacy-manifest-file-timestamp` (cut from `develop`, per
  `CLAUDE.md`).
- Commit style (Conventional Commits, per `CLAUDE.md`):
  `chore(ios): declare File Timestamp required-reason API in privacy manifest`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add the File Timestamp entry to the iOS manifest

In `BeachTennisCounter/iOS/PrivacyInfo.xcprivacy`, add a second `<dict>` to the
`NSPrivacyAccessedAPITypes` array, after the existing UserDefaults dict. The
array must end up containing exactly two dicts. The result must be:

```xml
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>C617.1</string>
			</array>
		</dict>
	</array>
```

Keep the tab indentation the rest of the file uses (the file is tab-indented,
not space-indented).

**Verify**:
- `plutil -lint BeachTennisCounter/iOS/PrivacyInfo.xcprivacy` → ends in `: OK`
- `grep -c NSPrivacyAccessedAPICategoryFileTimestamp BeachTennisCounter/iOS/PrivacyInfo.xcprivacy` → `1`
- `grep -c "C617.1" BeachTennisCounter/iOS/PrivacyInfo.xcprivacy` → `1`

### Step 2: Confirm nothing else changed

**Verify**:
- `grep -c FileTimestamp BeachTennisCounter/watchOS/PrivacyInfo.xcprivacy` → `0`
- `git status --porcelain` lists only `BeachTennisCounter/iOS/PrivacyInfo.xcprivacy`
  as modified (plus, if you updated it, `plans/README.md`).

## Test plan

No unit test — a privacy manifest is static metadata with no runtime behavior,
and the project has no XML-linting test harness. Verification is the
`plutil -lint` gate plus the `grep` checks in Step 1. (If you want end-to-end
proof, an archive + validate in Xcode would show the ITMS-91053 warning gone,
but that requires signing and is not part of this plan's gate.)

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `plutil -lint BeachTennisCounter/iOS/PrivacyInfo.xcprivacy` → `OK`
- [ ] `grep -c NSPrivacyAccessedAPICategoryFileTimestamp BeachTennisCounter/iOS/PrivacyInfo.xcprivacy` → `1`
- [ ] `grep -c "C617.1" BeachTennisCounter/iOS/PrivacyInfo.xcprivacy` → `1`
- [ ] `grep -c FileTimestamp BeachTennisCounter/watchOS/PrivacyInfo.xcprivacy` → `0`
- [ ] `git status` shows only the iOS manifest modified (plus `plans/README.md`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The iOS manifest no longer matches the "Current state" excerpt (someone
  already added an API entry, or restructured the file).
- `StoreRecovery.swift` no longer references `.creationDateKey` /
  `attributesOfItem` (the timestamp reads at lines 155 / 182 are gone) — then
  this declaration may be unnecessary; report rather than adding it anyway.
- `plutil -lint` reports the file invalid after your edit and one fix attempt
  doesn't resolve it (likely a stray tab/space or unbalanced tag).
- App Store Connect or Xcode's privacy report insists on a reason code other
  than `C617.1` for this category — report the code it wants; do not guess a
  different one.

## Maintenance notes

- If a future feature reads any other required-reason API — disk space
  (`NSPrivacyAccessedAPICategoryDiskSpace`), system boot time, or active
  keyboard — add its category here the same way. A quick audit: `grep -rn`
  the source for `creationDate`, `modificationDate`, `volumeAvailableCapacity`,
  `systemUptime`, `attributesOfItem`.
- Reviewer should scrutinize: that the entry was added to the **iOS** manifest
  only, and that the reason code matches the actual API use (app-group-container
  file timestamps → `C617.1`).
- Deferred: nothing. This is a complete, standalone compliance fix.
