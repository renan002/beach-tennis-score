# Automated release cutting: tag on merge, PAT for CI, PR-based merge-back

A GitHub Actions workflow cuts releases on manual `workflow_dispatch` (human supplies the version — semver bump type is a judgment call, not something to infer from commits): it branches `release/x.y.z` from `develop`, bumps `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in `project.yml` on that branch, and opens a PR into `main`. We deliberately do **not** tag at cut time — the tag and GitHub Release are created by a separate workflow when that PR actually merges into `main`, so a tag always means "this is what shipped," never a pre-merge snapshot that review feedback could still change. The cut workflow also does not re-run tests itself; it trusts `develop`'s own CI to already be green and relies on the release PR's CI run for the final check on the exact shipped commit.

## Merge mechanics (required, not stylistic)

- **The `release/x.y.z → main` PR and the `main → develop` merge-back PR must both land as merge commits — never squash or rebase.** Squashing collapses the branch to a single commit and severs its ancestry link to `develop`; every later merge-back then diffs against a stale common ancestor and surfaces every file `develop` has since touched as a spurious conflict, even when `develop` is merely ahead of `main`. The cut/publish workflows only *open* these PRs (a human still merges), so both PR bodies carry a loud merge-commit instruction, and `release-publish` emits a `::warning::` if the shipped merge commit has fewer than two parents. Durable enforcement lives in repo settings: **allow only merge commits for these branches** (disable squash/rebase) so the button default can't reintroduce the bug.
- **The merge-back PR's head is a disposable branch (`chore/sync-release-x.y.z-into-develop`) cut from `main`'s tip, not `main` itself.** `main` is protected (changes only via PR), so a merge-back opened with `head=main` has nowhere to push conflict-resolution commits and is unmergeable the moment any conflict appears. A throwaway branch has no protection ruleset, so conflicts can be resolved on it normally. Delete it after the merge-back lands.

## Keeping `project.pbxproj` in sync at cut time

`project.pbxproj` is checked in and hardcodes `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in its build settings — those, not `project.yml`, are what reach the built binary. The cut workflow therefore patches the same two keys in `project.pbxproj` immediately after bumping `project.yml`, and fails if the patch didn't take. We patch the two keys directly (via `perl`) rather than running `xcodegen generate`, because xcodegen needs a macOS runner and would reserialize the entire project (churning scheme/config files whenever CI's xcodegen version differs from a developer's). If a future structural change moves these keys, the workflow's post-patch assertion fails and the project must be regenerated with xcodegen and re-committed.

## Considered Options

- Default `GITHUB_TOKEN` for the branch push/PR creation — rejected because GitHub Actions does not trigger further workflow runs (including `ci.yml`'s `pull_request` trigger) on events performed with the default token, which would let a release PR merge without CI ever running on it. A PAT/App token is used instead specifically so CI fires normally.
- Direct push of `main` back into `develop` after merge — rejected in favor of an auto-opened merge-back PR, consistent with this repo's PR-based review for every other change and so conflicts surface to a human instead of silently auto-merging.
- Opening the merge-back PR with `head=main` directly — rejected: `main`'s protection ruleset leaves no way to push conflict-resolution commits, so any conflict makes the PR permanently unmergeable. A disposable sync branch off `main`'s tip is used as the head instead.
- Running `xcodegen generate` in the cut workflow to refresh `project.pbxproj` — rejected in favor of a direct two-key `perl` patch, to avoid a macOS runner and whole-project reserialization churn (see above).
- Reusing `.github/PULL_REQUEST_TEMPLATE.md` for the release PR — rejected; that template is framed around a single `Closes #<issue>`, which doesn't fit a release PR bundling many issues. The release PR body is an auto-generated changelog instead.

## Consequences

- Requires a PAT (or GitHub App installation token) stored as a repo secret, with a rotation plan — a permanent piece of operational upkeep this automation didn't have before.
- `develop`'s `MARKETING_VERSION` can drift behind `main` between a release merging and the merge-back PR actually being reviewed/merged; the next release-cut's validation (input must exceed `develop`'s current value) depends on that merge-back landing promptly.
