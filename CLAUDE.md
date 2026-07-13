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

**Combined iOS + watchOS build:** Use Xcode.app. CLI combined builds are blocked by a CoreSimulator version mismatch (1051.49 vs 1051.50) in this environment.

> After adding or removing any `.swift` file, always run `xcodegen generate` — the `.xcodeproj` won't pick up the new file automatically.

## Architecture

The project has two targets sharing a `Shared/` layer:

```
Shared/          ← compiled into both targets
  MatchState.swift    — all data models (Team, PointScore, GameRecord, MatchState)
  ScoreEngine.swift   — pure scoring logic, no UI imports
  WatchMessage.swift  — WatchConnectivity payload constants and MatchResultPayload

watchOS/         ← Apple Watch app (primary runtime UI)
  BeachTennisWatchApp.swift
  Views/          HomeView → ServeSelectionView → ScoreView → MatchHistoryView
  Services/WatchSessionManager.swift   — @MainActor singleton, WCSession delegate

iOS/             ← iPhone companion (history + settings)
  BeachTennisApp.swift
  Models/StoredMatch.swift             — @Model (SwiftData)
  Views/          MatchListView → MatchDetailView, SettingsView
  Services/PhoneSessionManager.swift   — @MainActor singleton, WCSession delegate
```

### Data flow

- **Scoring:** `ScoreView` holds `MatchState` + a `[MatchState]` undo stack. Every tap calls `ScoreEngine.awardPoint(to:state:)` — no mutation outside `ScoreEngine`.
- **Watch → iPhone:** At match end `WatchSessionManager.sendMatchResult(_:duration:)` calls `WCSession.transferUserInfo`. `PhoneSessionManager.session(_:didReceiveUserInfo:)` decodes via `MatchResultPayload.from(_:)` and inserts a `StoredMatch` into SwiftData.
- **iPhone → Watch (colors):** `PhoneSessionManager.pushSettingsToWatch()` calls `WCSession.updateApplicationContext` with hex strings. `WatchSessionManager.session(_:didReceiveApplicationContext:)` reads them on the watch (extracts `String?` values *before* any `Task { @MainActor in }` to satisfy Swift 6 `Sendable` rules).

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

- **iOS only:** `Color.toHex()` uses `UIColor` — lives in `PhoneSessionManager.swift`.
- **watchOS only:** `Color(hex:)` decode-only — lives in `WatchSessionManager.swift`. No `toHex()` on watch.

## Git workflow

### Branches

- New feature branches are always cut from `develop`, never from `main` or another feature branch.
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
