# Plan 010: Let users delete matches from the iOS history list

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5497f0b..HEAD -- BeachTennisCounter/iOS/Views/MatchListView.swift`
> If the file changed since this plan was written, compare the "Current state"
> excerpts against the live code before proceeding; on a mismatch, treat it as
> a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (soft: plan 001 for the test gate)
- **Category**: direction
- **Planned at**: commit `5497f0b`, 2026-07-12
- **Issue**: https://github.com/renan002/beach-tennis-score/issues/10

## Why this matters

Matches are created (synced from the watch) but can never be removed: no
`.onDelete`, no swipe action, no edit mode exists anywhere in the iOS app.
Test matches, abandoned rallies someone finished for fun, and mis-scored games
sit in the history forever. Swipe-to-delete is the standard, expected iOS
affordance for a `List` backed by user data, and SwiftData makes it a
few-line change.

## Current state

- `BeachTennisCounter/iOS/Views/MatchListView.swift:10-16` — the list's data
  is a **filtered computed array** over the `@Query` results:

```swift
@Query(sort: \StoredMatch.date, order: .reverse) private var allMatches: [StoredMatch]
@State private var filter: String = "all"

private var matches: [StoredMatch] {
    switch filter {
    case "beachTennis": return allMatches.filter { $0.matchTypeRaw == "beachTennis" }
    case "tennis":      return allMatches.filter { $0.matchTypeRaw == "tennis" }
    default:            return allMatches
    }
}
```

- `BeachTennisCounter/iOS/Views/MatchListView.swift:118-125` — the list to change:

```swift
private var matchList: some View {
    List(matches) { match in
        NavigationLink(destination: MatchDetailView(match: match)) {
            MatchRowView(match: match)
        }
    }
    .listStyle(.insetGrouped)
}
```

- Deletion goes through SwiftData's `ModelContext`. The view does not
  currently declare `@Environment(\.modelContext)`; the container is attached
  at the app root (`BeachTennisApp.swift:42` — `.modelContainer(container)`),
  so the environment context is available.
- Repo conventions: view logic in small `private func`s at the bottom of the
  struct (see `HomeView.handleNewMatch`); persistence writes end with
  `try? context.save()` (see `PhoneSessionManager.insertMatch`,
  `PhoneSessionManager.swift:100-101`). Match both.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Full test/build gate (compiles iOS files) | see "Verified commands" in `plans/README.md` (from plan 001); iOS target only compiles via the combined scheme | `** TEST SUCCEEDED **` |

## Scope

**In scope** (the only file you should modify):
- `BeachTennisCounter/iOS/Views/MatchListView.swift`

**Out of scope** (do NOT touch):
- `MatchDetailView.swift` — no delete button there in this plan (a toolbar
  delete on the detail screen is a fine follow-up, but it needs
  dismiss-after-delete handling; keep this plan to the list).
- `StoredMatch.swift`, `PhoneSessionManager.swift` — no model or sync changes.
- Confirmation dialogs / undo — swipe-to-delete is its own confirmation
  affordance on iOS; don't add alert friction.
- The watch target — deletion is a phone-side concern (history lives only in
  SwiftData on the phone).

## Git workflow

- Branch: `advisor/010-swipe-to-delete-matches`
- Commit style: `feat(ios): swipe-to-delete matches in history list`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add the model context and delete handler

In `MatchListView.swift`:

1. Add below the existing `@EnvironmentObject` (line 5):

```swift
@Environment(\.modelContext) private var modelContext
```

2. Add a private func at the bottom of the struct (after `matchList`):

```swift
private func deleteMatches(at offsets: IndexSet) {
    for index in offsets {
        modelContext.delete(matches[index])
    }
    try? modelContext.save()
}
```

Note: `offsets` indexes into the **filtered** `matches` array — indexing that
same array (never `allMatches`) is what keeps deletion correct while a filter
is active.

### Step 2: Switch the List to ForEach + onDelete

Replace the `matchList` body:

```swift
private var matchList: some View {
    List {
        ForEach(matches) { match in
            NavigationLink(destination: MatchDetailView(match: match)) {
                MatchRowView(match: match)
            }
        }
        .onDelete(perform: deleteMatches)
    }
    .listStyle(.insetGrouped)
}
```

(`@Query` re-evaluates on context changes, so the row disappears without any
manual state invalidation. The empty-state branch at lines 24-30 already
handles the list becoming empty.)

**Verify**: `grep -n "onDelete\|deleteMatches" BeachTennisCounter/iOS/Views/MatchListView.swift` → the `.onDelete(perform: deleteMatches)` line + 1 func definition.

### Step 3: Compile/test gate

Run the verified test command from `plans/README.md`.

**Verify**: `** TEST SUCCEEDED **`.

## Test plan

No new unit tests: the logic is a 4-line SwiftUI/SwiftData bridge with no seam
in the current test target (no UI-test infra in this repo; `deleteMatches` is
private view code). Gates: Step 2's grep and Step 3's compile/test run.
Manual QA note for the operator: with the filter set to "Tennis", swipe-delete
a row → that tennis match (and only it) is gone after switching the filter to
"All" and relaunching the app.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -c "onDelete" BeachTennisCounter/iOS/Views/MatchListView.swift` → 1
- [ ] Test command → `** TEST SUCCEEDED **`
- [ ] `git status` shows changes only to `MatchListView.swift`
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `matchList`/`matches` no longer match the "Current state" excerpts.
- You find yourself adding state, confirmation dialogs, or edit-mode toolbar
  buttons — the scope is swipe-to-delete only.
- Deleting from the filtered array appears to remove the wrong row in your
  reasoning — re-read the note in Step 1; if the data flow has changed (e.g.
  someone replaced the computed filter with a dynamic `@Query`), stop.

## Maintenance notes

- If the computed `matches` filter is ever replaced by a parameterized
  `@Query` (a natural future refactor), `deleteMatches` must move with it —
  the offsets must always index the array the `ForEach` renders.
- Follow-up explicitly deferred: delete from `MatchDetailView` (needs
  dismiss-after-delete), and any bulk "Clear history" action in Settings.
- Reviewer should scrutinize: deletion uses `matches[index]`, not
  `allMatches[index]`.
