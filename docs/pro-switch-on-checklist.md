# Switching Pro on

Pro is fully built and **dark**: `PRO_ON_SALE` is defined in `Debug` and `Dev`
and absent from `Release`, so shipped builds have no purchase surface and no Pro
gates. Turning Pro on is flipping that one value and cutting a release — there
is nothing to flip in a build that has already shipped, by design.

This is the procedure. It exists because the flip is a one-time event with
several steps that are only obvious while you are holding all of it in your
head, and because one of them will lock you out of merging if done in the wrong
order.

See [ADR 0008](adr/0008-build-time-feature-flags-per-build-configuration.md)
for the flag mechanism, ADR 0007 for the per-configuration machinery it rides
on, and
`scripts/validate-release-is-dark.sh` for the guard that stands in the way until
you deliberately remove it.

## Before flipping anything

- [ ] The in-app purchase `com.renan.beachtennis.pro` exists in App Store
      Connect with its Display Name, its pt-BR description (≤45 characters),
      price, and its App Review Screenshot. The screenshot was captured from a
      flag-on build launched from Xcode against `Pro.storekit`; it does not
      need recapturing.
- [ ] The IAP is attached to the app version being submitted. Our first
      non-consumable **must** go through review together with a binary — it
      cannot be reviewed on its own.
- [ ] The Pro pitch copy in `ProPurchaseSheet` says what you actually want to
      sell, in both languages.

## The flip

One commit, or one PR — the point is that it is a single reviewable diff.

- [ ] **Remove `release-is-dark` from the branch ruleset for `main` first.**
      Do this *before* opening the flip PR. The guard is a required status
      check, and the flip makes it fail; leave it required and the PR cannot
      merge. Delete the job while it is still required and the check never
      reports at all, which blocks merges just as hard and is more confusing.
- [ ] Add `PRO_ON_SALE` to the `Release` configuration in
      `BeachTennisCounter/project.yml`, then run `xcodegen generate` so
      `project.pbxproj` carries it. The pbxproj is what Xcode archives; a
      `project.yml` edit alone changes nothing.
- [ ] Delete `scripts/validate-release-is-dark.sh`,
      `scripts/test-validate-release-is-dark.sh`, and the `release-is-dark` job
      in `.github/workflows/ci.yml`. There is no bypass flag on purpose — the
      guard is removed honestly or not at all.
- [ ] Fix `ProEntitlementTests.testProOnSaleIsWiredOnInDebugAndDevAndAbsentFromRelease`,
      which asserts that exactly `Debug` and `Dev` define compilation
      conditions. It fails on the flip by design. Invert it: `Release` must now
      define `PRO_ON_SALE` too.
- [ ] Update ADR 0008 and `CONTEXT.md` to say Pro is on sale, and when.

`ProSurfaceTests` needs no changes. Its rules — every presenter of the purchase
sheet is gated, each of the three touchpoints reads the entitlement — stay true
with the flag on; they were written to describe the gates, not the darkness.

## Shipping it

- [ ] Merge the flip into `develop`, then run the **Release Cut** workflow.
- [ ] Merge the `release/x.y.z` PR into `main`. That merge is what triggers the
      **Xcode Cloud** build; nothing in this repository archives or uploads.
- [ ] **Exercise Pro on the resulting TestFlight build.** This is the first and
      only time anyone but a developer at a Mac touches the purchase surface
      before customers do — the whole dark period has none. Buy it with a
      sandbox account and confirm: the purchase completes, Restore works on a
      second device, Estatísticas unblurs, the Cartão loses its watermark
      *including on matches played before the purchase*, and Vários becomes
      selectable.
- [ ] Submit for review with the IAP attached.

## The release notes

State plainly that Estatísticas and Vários now require Pro — **in this
release's notes only**. Do not pre-announce it in a dark release.

Someone who set a sport preference will notice the watch has stopped asking, and
someone who opened Estatísticas will find it blurred. Unannounced, both read as
bugs, from exactly the most engaged users, on the release you most want to go
well. Announced, it is a stated trade with the remedy on the same screen.

This is the regression the map accepted when Pro was scoped: people who have
those two features free in 1.4/1.5 lose them. Buying Pro hands Vários straight
back, with nothing to re-pick — the stored setting was never rewritten.
