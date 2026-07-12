# Plan 002: Add full unit-test coverage for Tennis-mode scoring

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5497f0b..HEAD -- BeachTennisCounter/Shared/ScoreEngine.swift BeachTennisCounter/Shared/MatchState.swift BeachTennisCounter/Tests`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/001-ci-verification-baseline.md (provides the verified test command)
- **Category**: tests
- **Planned at**: commit `5497f0b`, 2026-07-12
- **Issue**: https://github.com/renan002/beach-tennis-score/issues/3

## Why this matters

Tennis mode (commit `ca652a9`) is the newest and most intricate logic in the engine — deuce/advantage, per-set game scoring, best-of-3 sets, tiebreak with win-by-2, and serve rotation across tiebreak sets — and it has **zero tests**. `Tests/ScoreEngineTests.swift` exercises beach tennis only (the default `MatchState()` has `matchType == .beachTennis`). This is a characterization-test plan: it pins the current tennis behavior so future engine changes (including plan 006) can't silently break it.

**These are characterization tests**: they must encode what the engine *does today*, per the excerpts below. If a test you write per this plan fails, the plan's description of current behavior is wrong or the code drifted — that is a STOP condition, not a cue to "fix" the engine.

## Current state

- `BeachTennisCounter/Shared/ScoreEngine.swift` — all scoring logic. Tennis path: `awardTennisPoint` (line 139) → `awardTennisGamePoint` (147) / `awardTennisTiebreakPoint` (257), `winTennisGame` (184), `checkTennisSetProgress` (211), `winTennisSet` (226).
- `BeachTennisCounter/Shared/MatchState.swift` — `MatchState` struct; tennis-relevant fields: `matchType`, `setsWonA/B`, `setHistory: [SetRecord]`, `advantageTeam: Team?`, plus the shared `setScoreA/B`, `pointA/B`, tiebreak fields, `servingTeam`, `isMatchOver`, `winner`.
- `BeachTennisCounter/Tests/ScoreEngineTests.swift` — existing beach-tennis tests; use its structure and helpers as the pattern (private `freshState`/`winGame` helpers, `test_<area>_<behavior>` naming, one behavior per test).
- Entry point dispatch, `ScoreEngine.swift:4-12`:

```swift
static func awardPoint(to team: Team, state: inout MatchState) {
    guard !state.isMatchOver else { return }
    if state.matchType == .tennis {
        awardTennisPoint(to: team, state: &state)
    } else {
        awardBeachTennisPoint(to: team, state: &state)
    }
}
```

Behavior to characterize (verified by reading `ScoreEngine.swift` at `5497f0b`):

1. **Game points** (`awardTennisGamePoint`, lines 147-182): normal 0→15→30→40 progression; if scorer's point is `.forty` and opponent's is not → game won. At 40-40 the *next* point awards `advantageTeam = scorer` (line 164-167). If scorer already has advantage → game (151-155). If *opponent* has advantage → `advantageTeam = nil` (back to deuce, 158-161). Reaching 40-40 by normal advancement does **not** set advantage (comment at 180-181).
2. **Game win side effects** (`winTennisGame`, 184-209): winner's `setScore` +1, points reset to zero, `advantageTeam = nil`, serve toggles, `GameRecord` appended with `gameScoreDisplay == "Ad"` when won from advantage, else `"40–30"`-style pre-win score.
3. **Set progression** (`checkTennisSetProgress`, 211-224): set won at ≥6 games with a 2-game lead; at 6-6 → `isTiebreak = true` and `tiebreakFirstServer = servingTeam`. 6-5 continues; 7-5 wins the set.
4. **Set win** (`winTennisSet`, 226-255): appends a `SetRecord`, increments `setsWonA/B`; **2 sets wins the match**; otherwise resets `setScoreA/B` to 0, clears tiebreak state, and — only after a tiebreak set — sets `servingTeam = tiebreakFirstServer.other` (lines 251-254).
5. **Tiebreak** (`awardTennisTiebreakPoint`, 257-297): first to ≥7 **with a 2-point margin**; appends a tiebreak `GameRecord` (with the set score already reflecting the tiebreak winner's game, e.g. `setScoreA: state.setScoreA + 1` at line 268), then increments `setScore` and calls `winTennisSet(isTiebreak: true)`. While unresolved, serve follows `tiebreakServer(pointsPlayed:firstServer:)` (1 point, then alternate every 2).
6. **Match over guard** (line 5): no state changes after `isMatchOver == true`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Regenerate project after adding the file | `cd BeachTennisCounter && xcodegen generate` | exit 0, "Created project" output |
| Run tests | see the "Verified commands" section of `plans/README.md` (recorded by plan 001); default: `cd BeachTennisCounter && xcodebuild test -project BeachTennisCounter.xcodeproj -scheme BeachTennisCounter -destination 'platform=iOS Simulator,name=iPhone 17'` | `** TEST SUCCEEDED **` |
| Watch-only compile check | `cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build` | `** BUILD SUCCEEDED **` |

If plan 001 recorded local tests as environment-blocked, the test gate is CI; in that case verify compilation of the test target via `xcodebuild build-for-testing` with the same scheme/destination, and note it in your report.

## Scope

**In scope** (the only files you should create/modify):
- `BeachTennisCounter/Tests/TennisScoreEngineTests.swift` (create)
- `BeachTennisCounter/BeachTennisCounter.xcodeproj/*` (regenerated by `xcodegen generate` — commit the regenerated project)

**Out of scope** (do NOT touch):
- `BeachTennisCounter/Shared/ScoreEngine.swift` — characterization only; if behavior looks wrong, STOP and report (plan 006 covers the one known rules change, in the *beach* path).
- `BeachTennisCounter/Tests/ScoreEngineTests.swift` — leave the beach-tennis suite as is.
- `BeachTennisCounter/project.yml` — the `Tests` directory is already a directory-source; no yml change needed for a new file inside it.

## Git workflow

- Branch: `advisor/002-tennis-scoring-tests`
- Commit style: `test(tennis): add ScoreEngine coverage for tennis mode`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Create the test file with helpers

Create `BeachTennisCounter/Tests/TennisScoreEngineTests.swift`:

```swift
import XCTest
@testable import BeachTennisCounter

final class TennisScoreEngineTests: XCTestCase {

    // MARK: - Helpers

    private func freshTennisState(server: Team = .a) -> MatchState {
        var s = MatchState()
        s.matchType = .tennis
        s.servingTeam = server
        s.initialServer = server
        s.tiebreakFirstServer = server
        return s
    }

    private func winGame(for team: Team, state: inout MatchState) {
        // From 0-0 (or any non-deuce start), 4 clean points win a game.
        for _ in 0..<4 { ScoreEngine.awardPoint(to: team, state: &state) }
    }

    private func winGames(_ count: Int, for team: Team, state: inout MatchState) {
        for _ in 0..<count { winGame(for: team, state: &state) }
    }

    /// Team A and B trade games until the current set is 6-6 (tiebreak active).
    private func stateAtTiebreak(server: Team = .a) -> MatchState {
        var state = freshTennisState(server: server)
        for _ in 0..<6 {
            winGames(1, for: .a, state: &state)
            winGames(1, for: .b, state: &state)
        }
        return state
    }
}
```

Then run `cd BeachTennisCounter && xcodegen generate` so the project picks up the new file.

**Verify**: `xcodegen generate` exits 0, and `grep -c "TennisScoreEngineTests" BeachTennisCounter/BeachTennisCounter.xcodeproj/project.pbxproj` → ≥ 1.

### Step 2: Add the deuce/advantage tests

Add to the class (each as a separate `func test_...`), asserting exactly this behavior:

1. `test_advantage_awardedWhenPointPlayedAtDeuce` — set `pointA = .forty; pointB = .forty`, award to `.a` → `advantageTeam == .a`, `setScoreA == 0` (no game yet).
2. `test_advantage_reachingDeuceByAdvancementDoesNotAward` — `pointA = .forty; pointB = .thirty`, award to `.b` → `pointB == .forty`, `advantageTeam == nil`.
3. `test_advantage_holderWinsGame` — deuce state with `advantageTeam = .a`, award to `.a` → `setScoreA == 1`, `advantageTeam == nil`, both points `.zero`.
4. `test_advantage_opponentScores_backToDeuce` — deuce state with `advantageTeam = .a`, award to `.b` → `advantageTeam == nil`, `setScoreA == 0 && setScoreB == 0`, points still `.forty`/`.forty`.
5. `test_advantage_gameRecordShowsAd` — deuce, advantage `.a`, award `.a` → `state.gameHistory.last?.gameScoreDisplay == "Ad"`.
6. `test_game_fortyBeatsThirty_winsGame` — `pointA = .forty; pointB = .thirty`, award `.a` → `setScoreA == 1`, serve rotated to `.b` (start server `.a`).

**Verify**: run the test command → `** TEST SUCCEEDED **` (or `build-for-testing` succeeds under the CI-only fallback).

### Step 3: Add set-progression tests

1. `test_set_wonAtSixLove` — `winGames(6, for: .a)` from fresh → `setsWonA == 1`, `setScoreA == 0 && setScoreB == 0` (reset for next set), `setHistory.count == 1`, `setHistory[0].gamesA == 6 && gamesB == 0`, `isMatchOver == false`.
2. `test_set_notWonAtSixFive` — trade games to 5-5 (`5×(A game, B game)`), then one more A game → `setScoreA == 6, setScoreB == 5`, `setsWonA == 0`, `isTiebreak == false`.
3. `test_set_wonAtSevenFive` — from 6-5 above, one more A game → `setsWonA == 1`, `setHistory[0].gamesA == 7 && gamesB == 5`.
4. `test_tiebreak_startsAtSixSix` — `stateAtTiebreak()` → `isTiebreak == true`, `setScoreA == 6 && setScoreB == 6`, `isMatchOver == false`.

**Verify**: test command → all pass.

### Step 4: Add tiebreak tests (including win-by-2)

1. `test_tiebreak_sevenZeroWinsSet` — `stateAtTiebreak()`, 7 points to `.a` → `setsWonA == 1`, `isTiebreak == false`, `tiebreakA == 0` (reset), `setHistory[0].isTiebreak == true`, `setHistory[0].gamesA == 7 && gamesB == 6`.
2. `test_tiebreak_sevenSixDoesNotWin` — `stateAtTiebreak()`, 6 points `.a`, 6 points `.b`, 1 point `.a` (7-6) → `isTiebreak == true`, `setsWonA == 0`.
3. `test_tiebreak_eightSixWins` — continue from 7-6 with one more `.a` point → `setsWonA == 1`.
4. `test_tiebreak_gameRecordScore` — after `test_tiebreak_sevenZeroWinsSet` sequence → `gameHistory.last?.isTiebreak == true`, `gameHistory.last?.gameScoreDisplay == "7–0"` (en-dash `–`, matching the engine's format at `ScoreEngine.swift:265`).
5. `test_tiebreak_serveRotation` — `stateAtTiebreak(server:)`: note that after 12 traded games the serving team has toggled 12 times, so `servingTeam` equals the original first server and `tiebreakFirstServer == servingTeam` at tiebreak start. Award 1 point → `servingTeam == tiebreakFirstServer.other`; award 2 more → back to `tiebreakFirstServer`. (Read `state.tiebreakFirstServer` from the state rather than assuming, to keep the test robust.)
6. `test_tiebreak_nextSetServerIsOtherOfTiebreakFirstServer` — win the tiebreak 7-0 for `.a`, then → `servingTeam == <tiebreakFirstServer just before the win>.other`. Capture `tiebreakFirstServer` into a local before awarding the 7 points (it is reset by `winTennisSet`).

**Verify**: test command → all pass.

### Step 5: Add best-of-3 match tests

1. `test_match_twoSetsWinsMatch` — `winGames(6, for: .a)` twice from fresh → `setsWonA == 2`, `isMatchOver == true`, `winner == .a`, `setHistory.count == 2`.
2. `test_match_splitSetsGoesToThird` — A wins set 1 (6 games), B wins set 2 (6 games) → `isMatchOver == false`, `setsWonA == 1 && setsWonB == 1`; then A wins set 3 → `isMatchOver == true`, `winner == .a`.
3. `test_match_noScoringAfterMatchOver` — from a finished match, award another point → `setsWonA`, `setScoreA`, `pointA` all unchanged.

**Verify**: test command → full suite passes, including all pre-existing beach-tennis tests.

## Test plan

This plan *is* the test plan. Structural pattern: `BeachTennisCounter/Tests/ScoreEngineTests.swift` (same helper style, naming, one-assertion-cluster-per-behavior). Expected new test count: ~19. Final verification: the repo's test command → `** TEST SUCCEEDED **`, total test count strictly greater than before (previously 3 test classes).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `BeachTennisCounter/Tests/TennisScoreEngineTests.swift` exists with ≥ 18 `func test_` methods (`grep -c "func test_" ...` ≥ 18)
- [ ] `xcodegen generate` was run; `grep -c "TennisScoreEngineTests" BeachTennisCounter/BeachTennisCounter.xcodeproj/project.pbxproj` ≥ 1
- [ ] Test command (per `plans/README.md` "Verified commands") → `** TEST SUCCEEDED **`, zero failures (or, under the documented CI-only fallback, `build-for-testing` succeeds and this is stated in the report)
- [ ] `git status` shows changes only to the in-scope files
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- Any test written exactly per Steps 2–5 fails: that means the engine's current behavior differs from this plan's characterization (or the engine drifted since `5497f0b`). Report the failing test and the observed vs. expected values. Do NOT change `ScoreEngine.swift` to make a test pass, and do NOT weaken the assertion.
- `ScoreEngine.swift` or `MatchState.swift` differ from the excerpts in "Current state".
- The test target fails to build for a reason unrelated to your new file.

## Maintenance notes

- Plan 006 changes the *beach* tiebreak to win-by-2; these tennis tests are unaffected but are the template for the tests plan 006 adds.
- If a "match tiebreak / 10-point super tiebreak instead of a third set" feature is ever added, `test_match_splitSetsGoesToThird` is the test that will need revisiting.
- Reviewer focus: check that assertions encode engine behavior (characterization), not ITF-rulebook idealizations.
