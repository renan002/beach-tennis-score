# Skip CI build/test on PRs that touch no app files

`ci.yml` no longer runs on `push` — only on `pull_request`. A first step in the single `test` job computes `git diff --name-only origin/${{ github.base_ref }}...HEAD` (checkout uses `fetch-depth: 0` to make this diff possible) and sets an `app_changed` output based on whether any changed path falls under `BeachTennisCounter/` or is `.github/workflows/ci.yml` itself. Every later step (`Select Xcode`, `Show toolchain`, `Build watchOS target`, `Run unit tests`) is gated on `if: steps.check.outputs.app_changed == 'true'`. When a PR only touches docs/plans/etc., those steps report as skipped and the job succeeds — CI returns success without spending the ~45-minute macOS runner budget on a build that can't have changed.

## Considered Options

- Skip via the workflow-level `on.pull_request.paths:` filter instead of an in-job check — rejected because a filtered-out workflow run reports no status at all for that commit, which breaks required-status-check branch protection (the check never appears as either passing or skipped).
- Two jobs (a cheap "changes" job feeding a gated "test" job via `needs`) — rejected in favor of a single job with a gating step; simpler, and this repo has one job today so there's no isolation benefit to splitting it.
- `dorny/paths-filter` (or similar marketplace action) for the diff — rejected in favor of raw `git diff`; the repo currently has zero third-party actions besides `actions/checkout`, and the matching logic here is simple enough not to justify the added supply-chain surface.
- Keeping the `push` trigger (as a safety net on `develop`/`main` themselves) — rejected; only `pull_request` remains, so a merge that combines unrelated changes is only checked at PR time, not re-verified on push to the target branch.

## Consequences

- `fetch-depth: 0` makes checkout slightly slower on every run, in exchange for the diff being reliable regardless of shallow-history edge cases.
- Because `push` is no longer a trigger, nothing re-runs CI against `develop`/`main` after merge; correctness depends entirely on the PR's own CI run reflecting the exact merged state.
- The app-file path list (`BeachTennisCounter/`, `.github/workflows/ci.yml`) is hand-maintained in the workflow; a new top-level app directory would need this list updated or it would silently skip CI for changes to it.
