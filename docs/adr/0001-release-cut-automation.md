# Automated release cutting: tag on merge, PAT for CI, PR-based merge-back

A GitHub Actions workflow cuts releases on manual `workflow_dispatch` (human supplies the version — semver bump type is a judgment call, not something to infer from commits): it branches `release/x.y.z` from `develop`, bumps `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in `project.yml` on that branch, and opens a PR into `main`. We deliberately do **not** tag at cut time — the tag and GitHub Release are created by a separate workflow when that PR actually merges into `main`, so a tag always means "this is what shipped," never a pre-merge snapshot that review feedback could still change. The cut workflow also does not re-run tests itself; it trusts `develop`'s own CI to already be green and relies on the release PR's CI run for the final check on the exact shipped commit.

## Considered Options

- Default `GITHUB_TOKEN` for the branch push/PR creation — rejected because GitHub Actions does not trigger further workflow runs (including `ci.yml`'s `pull_request` trigger) on events performed with the default token, which would let a release PR merge without CI ever running on it. A PAT/App token is used instead specifically so CI fires normally.
- Direct push of `main` back into `develop` after merge — rejected in favor of an auto-opened `main → develop` PR, consistent with this repo's PR-based review for every other change and so conflicts surface to a human instead of silently auto-merging.
- Reusing `.github/PULL_REQUEST_TEMPLATE.md` for the release PR — rejected; that template is framed around a single `Closes #<issue>`, which doesn't fit a release PR bundling many issues. The release PR body is an auto-generated changelog instead.

## Consequences

- Requires a PAT (or GitHub App installation token) stored as a repo secret, with a rotation plan — a permanent piece of operational upkeep this automation didn't have before.
- `develop`'s `MARKETING_VERSION` can drift behind `main` between a release merging and the merge-back PR actually being reviewed/merged; the next release-cut's validation (input must exceed `develop`'s current value) depends on that merge-back landing promptly.
