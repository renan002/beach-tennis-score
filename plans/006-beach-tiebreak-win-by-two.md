# Plan 006: Make the beach tennis super tiebreak win-by-2

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5497f0b..HEAD -- BeachTennisCounter/Shared/ScoreEngine.swift BeachTennisCounter/Tests/ScoreEngineTests.swift CLAUDE.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: MED (changes live scoring behavior users may have habituated to)
- **Depends on**: plans/001-ci-verification-baseline.md, plans/002-tennis-scoring-tests.md (engine test baseline should exist before engine changes)
- **Category**: bug (rules)
- **Planned at**: commit `5497f0b`, 2026-07-12
- **Issue**: https://github.com/renan002/beach-tennis-score/issues/6

## Why this matters

At 6-6 games, beach tennis mode plays a super tiebreak that currently ends the moment either team reaches 7 points — including at **7-6**. ITF beach tennis tiebreak rules require a 2-point margin, and this repo's own *tennis* tiebreak already implements win-by-2 (`ScoreEngine.swift:264,278`), so the two modes are inconsistent with each other. This plan aligns the beach tiebreak to win-by-2 and updates the documented rules in `CLAUDE.md`.

**Decision note for the reviewer**: `CLAUDE.md` currently documents the beach rule as "super tiebreak to 7 points" without a margin clause, so sudden-death *may* have been a deliberate house rule. The maintainer selected this finding for planning; the plan implements win-by-2 as the default. If the maintainer states sudden-death was intentional, the correct change is documentation-only (make `CLAUDE.md` say "sudden death at 7") — see STOP conditions.

## Current state

- `BeachTennisCounter/Shared/ScoreEngine.swift:98-135` — `awardBeachTennisTiebreakPoint`; the two win checks are sudden-death:

```swift
// ScoreEngine.swift:102 (team A) and :116 (team B)
if state.tiebreakA >= 7 {
    ...
}
if state.tiebreakB >= 7 {
    ...
}
```

Each branch builds a `display` string, increments the winner's `setScore`, appends a tiebreak `GameRecord`, and calls `endMatch`. The serve-rotation call at lines 131-134 runs only when neither branch fired.

- Contrast, the tennis tiebreak at `ScoreEngine.swift:264` / `:278` (the pattern to mirror):

```swift
if a >= 7 && (a - b) >= 2 { ... }
if b >= 7 && (b - a) >= 2 { ... }
```

- `BeachTennisCounter/Tests/ScoreEngineTests.swift` — existing beach tiebreak tests: `test_tiebreak_winAtSevenZero` (7-0), `test_tiebreak_winAtSevenFive` (7-5), `test_tiebreak_appendsGameRecord`, `test_tiebreak_noPointsAfterMatchOver`, and the `stateAt6_6()` helper (lines 25-32). None asserts an outcome at 7-6, so **no existing test changes under win-by-2** — they must all still pass untouched.
- `CLAUDE.md`, "Beach Tennis scoring rules" section: `- At 6-6 games: super tiebreak to 7 points; serve rotation ...`

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Watch-only compile check | `cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build` | `** BUILD SUCCEEDED **` |
| Run tests | see "Verified commands" in `plans/README.md` (from plan 001) | `** TEST SUCCEEDED **` |

No new files → no `xcodegen generate` needed.

## Scope

**In scope** (the only files you should modify):
- `BeachTennisCounter/Shared/ScoreEngine.swift` (the two conditions in `awardBeachTennisTiebreakPoint` only)
- `BeachTennisCounter/Tests/ScoreEngineTests.swift` (add tests; modify none)
- `CLAUDE.md` (one line in the scoring-rules section)

**Out of scope** (do NOT touch):
- The tennis tiebreak (`awardTennisTiebreakPoint`) — already correct.
- `checkBeachTennisMatchProgress` — the 7-game / 6-game match logic is unrelated.
- The tiebreak serve-rotation logic and `tiebreakServer` — unchanged by this rule.
- Refactoring the A/B branch duplication in `awardBeachTennisTiebreakPoint` — tempting, but keep this diff minimal and behavior-focused.

## Git workflow

- Branch: `advisor/006-beach-tiebreak-win-by-two`
- Commit style: `fix(scoring): require 2-point margin in beach tennis super tiebreak`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Change the two win conditions

In `BeachTennisCounter/Shared/ScoreEngine.swift`, `awardBeachTennisTiebreakPoint`:

- Line 102: `if state.tiebreakA >= 7 {` → `if state.tiebreakA >= 7 && (state.tiebreakA - state.tiebreakB) >= 2 {`
- Line 116: `if state.tiebreakB >= 7 {` → `if state.tiebreakB >= 7 && (state.tiebreakB - state.tiebreakA) >= 2 {`

No other lines in the function change. (The serve-rotation tail now also runs for 7-6-and-beyond states, which is correct — the tiebreak is still live.)

**Verify**: watch-only build → `** BUILD SUCCEEDED **`.

### Step 2: Add regression tests

In `BeachTennisCounter/Tests/ScoreEngineTests.swift`, under the existing `// MARK: - Tiebreak` section, add (using the existing `stateAt6_6()` helper):

```swift
func test_tiebreak_sevenSixDoesNotWin() {
    var state = stateAt6_6()
    for _ in 0..<6 { ScoreEngine.awardPoint(to: .a, state: &state) }
    for _ in 0..<6 { ScoreEngine.awardPoint(to: .b, state: &state) }
    ScoreEngine.awardPoint(to: .a, state: &state) // 7-6
    XCTAssertFalse(state.isMatchOver)
    XCTAssertTrue(state.isTiebreak)
    XCTAssertEqual(state.tiebreakA, 7)
    XCTAssertEqual(state.tiebreakB, 6)
}

func test_tiebreak_eightSixWins() {
    var state = stateAt6_6()
    for _ in 0..<6 { ScoreEngine.awardPoint(to: .a, state: &state) }
    for _ in 0..<6 { ScoreEngine.awardPoint(to: .b, state: &state) }
    ScoreEngine.awardPoint(to: .a, state: &state) // 7-6
    ScoreEngine.awardPoint(to: .a, state: &state) // 8-6
    XCTAssertTrue(state.isMatchOver)
    XCTAssertEqual(state.winner, .a)
    XCTAssertEqual(state.gameHistory.last?.gameScoreDisplay, "8–6")
}

func test_tiebreak_winByTwoSymmetricForB() {
    var state = stateAt6_6()
    for _ in 0..<6 { ScoreEngine.awardPoint(to: .b, state: &state) }
    for _ in 0..<6 { ScoreEngine.awardPoint(to: .a, state: &state) }
    ScoreEngine.awardPoint(to: .b, state: &state) // 6-7
    XCTAssertFalse(state.isMatchOver)
    ScoreEngine.awardPoint(to: .b, state: &state) // 6-8
    XCTAssertTrue(state.isMatchOver)
    XCTAssertEqual(state.winner, .b)
}
```

(Display string uses the en-dash `–`, matching `ScoreEngine.swift:103`.)

**Verify**: test command → `** TEST SUCCEEDED **`; the pre-existing tiebreak tests (`test_tiebreak_winAtSevenZero`, `test_tiebreak_winAtSevenFive`, etc.) pass **unmodified**.

### Step 3: Update the documented rule

In `CLAUDE.md`, change:

`- At 6-6 games: super tiebreak to 7 points; serve rotation ...`

to:

`- At 6-6 games: super tiebreak to 7 points, win by 2; serve rotation ...`

(keep the rest of the line intact).

**Verify**: `grep -n "win by 2" CLAUDE.md` → 1 match on the super-tiebreak line.

## Test plan

Step 2's three tests: the regression this plan exists for (7-6 continues), the new win condition (8-6 ends), and B-side symmetry. Pattern: the existing tiebreak tests in the same file. Full suite (including plan 002's tennis tests, if landed) must pass with zero modifications to existing tests.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -n "tiebreakA >= 7 && \|tiebreakB >= 7 && " BeachTennisCounter/Shared/ScoreEngine.swift` → 2 matches (both in the beach function)
- [ ] Test command → `** TEST SUCCEEDED **` with the 3 new tests present and passing
- [ ] `git diff --stat` touches only the 3 in-scope files
- [ ] `grep -n "win by 2" CLAUDE.md` → 1 match
- [ ] No existing test method bodies were modified (`git diff BeachTennisCounter/Tests/ScoreEngineTests.swift` shows additions only)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The operator/maintainer indicates (in the issue, the plan index, or your dispatch instructions) that sudden-death at 7 was intentional — then this becomes a CLAUDE.md-doc-only change and needs re-scoping.
- Any *existing* test fails after Step 1 — that would mean an existing test encoded the 7-6 sudden-death outcome, contradicting this plan's read of the suite; report it rather than editing the old test.
- The line numbers/conditions in "Current state" don't match the live `ScoreEngine.swift`.

## Maintenance notes

- Behavior change is user-visible: matches that would have ended 7-6 now continue. Worth one line in release notes.
- If undo behavior around match end ever gets reworked (`ScoreView`'s history stack), the "tiebreak still live at 7-6" states created here are ordinary states — no special handling needed.
- Deferred: unifying the near-duplicate A/B branches in `awardBeachTennisTiebreakPoint` (and its tennis twin) into one parametrized helper — do it only with the full engine suite (plans 002 + this) green first.
