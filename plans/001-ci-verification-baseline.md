# Plan 001: Establish a CI + local test verification baseline

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5497f0b..HEAD -- BeachTennisCounter/project.yml BeachTennisCounter/Tests .github`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `5497f0b`, 2026-07-12
- **Issue**: https://github.com/renan002/beach-tennis-score/issues/2

## Why this matters

The repo has three real test files (`BeachTennisCounter/Tests/ScoreEngineTests.swift`, `MatchResultPayloadTests.swift`, `PointScoreTests.swift`) but nothing ever runs them: there is no `.github/` directory at all, and `CLAUDE.md` documents that combined iOS+watchOS CLI builds are blocked locally by a CoreSimulator version mismatch. Every subsequent plan in `plans/` needs a trustworthy "run the tests" command. This plan (a) determines and records the working local test command, and (b) adds a GitHub Actions workflow so tests run on every push/PR regardless of local environment quirks.

## Current state

- `.github/` — does not exist. No CI of any kind.
- `BeachTennisCounter/BeachTennisCounter.xcodeproj/project.pbxproj` — **committed to git** (regenerated via `xcodegen generate` from `project.yml`). CI does not need to install XcodeGen as long as the committed project is current; regenerating in CI anyway is a cheap consistency check.
- `BeachTennisCounter/project.yml:84-98` — the shared `BeachTennisCounter` scheme has a test action wired to the `BeachTennisCounterTests` target:

```yaml
schemes:
  BeachTennisCounter:
    build:
      targets:
        BeachTennisCounter: all
        BeachTennisCounterWatch: all
        BeachTennisCounterTests: [testing]
    ...
    test:
      config: Debug
      targets:
        - BeachTennisCounterTests
```

- `BeachTennisCounter/project.yml:22-32` — `BeachTennisCounterTests` is an iOS `bundle.unit-test` target depending on the `BeachTennisCounter` app target, which itself depends on `BeachTennisCounterWatch` (`project.yml:61-62`). So `xcodebuild test` builds **both platforms** — this is the combination `CLAUDE.md` says is locally fragile.
- Deployment targets are iOS 26.0 / watchOS 26.0, Swift 6 (`project.yml:2-18`). Building requires **Xcode 26.x**. The locally installed SDKs are `iphonesimulator26.5` / `watchsimulator26.5` (note: `CLAUDE.md` still says 26.4 — it has drifted).
- Repo conventions: commit messages use conventional-commit-style prefixes (e.g. `feat(tennis): Implemented Tennis mode for the App`).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Watch-only build (known-good) | `cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build` | `** BUILD SUCCEEDED **` |
| Run tests (to be validated in Step 1) | `cd BeachTennisCounter && xcodebuild test -project BeachTennisCounter.xcodeproj -scheme BeachTennisCounter -destination 'platform=iOS Simulator,name=iPhone 17'` | `** TEST SUCCEEDED **` |
| List available simulators (if the destination name is wrong) | `xcrun simctl list devices available \| grep -i iphone` | at least one iPhone device listed |
| YAML sanity check | `ruby -ryaml -e 'YAML.load_file(".github/workflows/ci.yml"); puts "ok"'` (from repo root) | prints `ok` |

## Scope

**In scope** (the only files you should create/modify):
- `.github/workflows/ci.yml` (create)
- `plans/README.md` (add a "Verified commands" section + status row)
- `CLAUDE.md` (update the build-commands section with the verified test command and correct SDK version)

**Out of scope** (do NOT touch):
- `BeachTennisCounter/project.yml` and the `.xcodeproj` — no target/scheme changes are needed.
- Any `.swift` file.
- Code signing / archive / TestFlight anything — this is a build-and-test workflow only.

## Git workflow

- Branch: `advisor/001-ci-verification-baseline`
- Commit style: `ci: add GitHub Actions test workflow` (match the repo's `type(scope): description` convention)
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Determine the working local test command

Run, from `BeachTennisCounter/`:

```
xcodebuild test -project BeachTennisCounter.xcodeproj -scheme BeachTennisCounter -destination 'platform=iOS Simulator,name=iPhone 17'
```

If the device name is rejected, pick any available iPhone from `xcrun simctl list devices available` and substitute it. Three possible outcomes:

1. `** TEST SUCCEEDED **` — record this exact command (with the working device name) as the verified local test command. Continue.
2. Compile/test failures in the test code itself — STOP condition (the suite is broken at baseline; report which tests fail).
3. A CoreSimulator/environment error (e.g. version-mismatch messages, simulator service failures) before tests run — this is the known local limitation from `CLAUDE.md`. Record "local `xcodebuild test` blocked by <exact error>" and continue; CI becomes the primary test gate.

**Verify**: one of outcomes 1 or 3 is recorded in writing (you will put it in `plans/README.md` in Step 4).

### Step 2: Create the GitHub Actions workflow

Create `.github/workflows/ci.yml` with exactly this content (adjust only the two `<...>` markers per the instructions below):

```yaml
name: CI

on:
  push:
    branches: [develop, main]
  pull_request:

jobs:
  test:
    runs-on: macos-26
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_26.app || sudo xcode-select -s "$(ls -d /Applications/Xcode_26*.app | sort -V | tail -1)"

      - name: Show toolchain
        run: |
          xcodebuild -version
          xcrun simctl list devices available | grep -i iphone | head -5

      - name: Build watchOS target
        working-directory: BeachTennisCounter
        run: |
          xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build \
            CODE_SIGNING_ALLOWED=NO

      - name: Run unit tests
        working-directory: BeachTennisCounter
        run: |
          DEVICE=$(xcrun simctl list devices available | grep -oE 'iPhone [^(]+' | head -1 | xargs)
          xcodebuild test -project BeachTennisCounter.xcodeproj \
            -scheme BeachTennisCounter \
            -destination "platform=iOS Simulator,name=${DEVICE}" \
            CODE_SIGNING_ALLOWED=NO
```

Notes:
- `runs-on: macos-26` is required because the project needs the iOS 26 SDK. If GitHub's runner image catalog has renamed it by the time you execute this, use the newest macOS image that ships Xcode 26.x (check https://github.com/actions/runner-images if you have web access; otherwise keep `macos-26` — a wrong label fails fast and visibly on the first run, which is acceptable).
- The `DEVICE=$(...)` line makes the workflow independent of exact simulator names on the runner image.
- `CODE_SIGNING_ALLOWED=NO` avoids signing failures on runners with no certificates.

**Verify**: `ruby -ryaml -e 'YAML.load_file(".github/workflows/ci.yml"); puts "ok"'` (repo root) → prints `ok`.

### Step 3: Update CLAUDE.md build commands

In `CLAUDE.md`, in the "Build Commands" section:
- Change `xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator26.4` to the unversioned `-sdk watchsimulator` (the installed SDK is now 26.5 and will keep moving).
- Add the test command determined in Step 1 (or, if outcome 3, add: "Tests run in CI (`.github/workflows/ci.yml`); local `xcodebuild test` is blocked by <error>").

**Verify**: `grep -n "watchsimulator" CLAUDE.md` → shows the unversioned form; `grep -n "ci.yml\|xcodebuild test" CLAUDE.md` → at least one match.

### Step 4: Record verified commands in plans/README.md

Add (or update) a `## Verified commands` section in `plans/README.md` containing: the watch-only build command, and the test command with its Step-1 outcome (works locally / CI-only). Later plans (002–006) reference this section.

**Verify**: `grep -n "Verified commands" plans/README.md` → match found.

## Test plan

No new tests — this plan makes the existing 3 test files runnable/enforced. The existing suite passing (locally or the workflow being syntactically valid for CI) is the test.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `.github/workflows/ci.yml` exists and the ruby YAML check prints `ok`
- [ ] Step 1 outcome recorded in `plans/README.md` under "Verified commands"
- [ ] `CLAUDE.md` no longer references `watchsimulator26.4`
- [ ] `cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build` → `** BUILD SUCCEEDED **` (proves the environment still builds)
- [ ] `git status` shows no modified files outside the in-scope list
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- Step 1 outcome 2: existing tests fail to compile or fail assertions at baseline commit — the suite is broken and must be triaged by a human before CI would be green.
- There is no Xcode 26.x on this machine (`xcodebuild -version` shows < 26) — the toolchain assumption is false.
- You find an existing CI config anywhere (e.g. `.circleci/`, `fastlane/`) — reconcile with the operator instead of adding a parallel system.

## Maintenance notes

- The first real validation of the workflow happens on the next push — the operator should watch the first run; runner image labels and Xcode app paths are the most likely first-run failures (both fail loudly and are one-line fixes).
- Plans 002–006 all use the test command recorded here as their verification gate.
- Deferred: caching (DerivedData), watchOS-simulator test target, and running `xcodegen generate` in CI to detect a stale committed `.xcodeproj`. All are nice-to-haves once the basic gate is green.
