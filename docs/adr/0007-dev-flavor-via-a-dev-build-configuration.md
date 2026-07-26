# The dev flavor is a third build configuration, not a duplicate target

A dev build has to install alongside the App Store app on the developer's own
iPhone and Apple Watch, with its own data, so that unreleased migrations and
half-finished features can never touch a real Match History. That means a second
bundle id, and the question is where the second bundle id comes from.

**It comes from a third build configuration, `Dev`, a debug variant alongside
`Debug` and `Release`.** Three build settings vary with it —
`BUNDLE_ID_SUFFIX`, `APP_DISPLAY_NAME`, `APPICON_SUFFIX` — and everything else
is derived from them by build-setting expansion: the iOS bundle id, the watch
bundle id, `WKCompanionAppBundleIdentifier`, the App Group in both the
entitlement and the Info.plist, the icon asset name. Adding a flavor is a new
`configs` entry and nothing more; no file names a flavored value twice.

The prior art is one-sided. Firefox iOS, DuckDuckGo iOS and Telegram iOS all
flavor by configuration with a single bundle-id variable, and **duplicate
targets appear in none of the large apps surveyed** — Telegram states the
motivation in a comment next to the derivation, that one target should build
every flavor with no post-build plist patching. Duplicate targets were rejected
on that evidence: a second pair of app targets doubles the surface that has to
stay in sync (sources, dependencies, capabilities, schemes, the watch
embedding) to buy nothing this project needs.

The less obvious rejection is the cheap one: **making plain `Debug` the dev
flavor**, two configurations instead of three. That is why a third
configuration exists at all — under two, the production bundle id would only
ever exist in a Release build, so a crash or a signing problem specific to
`com.renan.beachtennis` could not be reproduced under the debugger. `Debug`
deliberately stays unflavored.

Full prior art, including the diff that was applied to a scratch copy and
built: [`docs/research/143-dev-flavor-side-by-side-install-prior-art.md`](../research/143-dev-flavor-side-by-side-install-prior-art.md).

## Two things this rests on that are easy to break later

**Entitlements files expand build settings.** The whole scheme depends on
`group.$(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)` in the `.entitlements` resolving at
build time. Apple documents this for `Info.plist` and never states it plainly in
prose for entitlements; it is corroborated by Apple's own project templates and
by DuckDuckGo's shipping entitlement, and it was observed directly in a
generated `.xcent` in the simulator and then on device. Treat it as verified by
observation, not by documentation — if it ever stops holding, the symptom is a
dev build silently signing for the *production* App Group.

**XcodeGen's `settings.configs` keys match by case-insensitive substring**
unless the key is an exact configuration name. `Dev` is exact, so it is safe
today. A configuration later named `Development` — or any name containing
"dev" — would silently inherit every Dev setting, including the flavored bundle
id. The configuration name is load-bearing in a way nothing in `project.yml`
would make obvious.

## Consequences

- `scripts/validate-bundle-ids.sh` guards the derivation in CI: it asserts the
  six target/configuration bundle ids against a fixed table *and* that
  `PRODUCT_BUNDLE_IDENTIFIER == BASE_BUNDLE_ID + BUNDLE_ID_SUFFIX`, which is
  what proves the entitlement's `group.$(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)` and
  the plist's `group.$(PRODUCT_BUNDLE_IDENTIFIER)` name the same App Group. The
  unit suite cannot catch this — its one configuration-sensitive test asserts
  the group *tracks* the bundle id, which stays true when the bundle id is
  wrong.
- `DEVELOPMENT_TEAM` and `CODE_SIGN_STYLE` had to move into `project.yml`:
  picking a team in Xcode's Signing & Capabilities tab writes it into the
  `.xcodeproj`, which `xcodegen generate` then discards.
- Build-setting expansion does not reach `.strings` files, and a localized
  `InfoPlist.strings` outranks `CFBundleDisplayName` — so `APP_DISPLAY_NAME`
  alone did not rename the app on a pt-BR device.
  `scripts/flavor-localized-app-name.sh` rewrites the name in the built product
  as a post-build phase on both app targets.
- Automatic signing registered both `.dev` App IDs and attached HealthKit
  unprompted, but **not** App Groups. Registering
  `group.com.renan.beachtennis.dev` and attaching it to the iOS App ID by hand
  in the developer portal was the one manual step; the research had this marked
  unconfirmed, and it is now the answer.
- The `.watchkitapp` suffix requirement on the companion watch app survives only
  in archived, WatchKit-extension-era Apple documentation — no current page
  restates it for single-target watch apps. It is followed here because Telegram
  derives the same suffix in a shipping build and because the pairing works;
  nobody should expect to find a live Apple page confirming it.
- Schemes **Beach Dev** and **Beach Dev Watch** run the configuration, and
  neither has an archive action — the dev flavor is a local Xcode install, not a
  distribution. The existing schemes stay on `Debug`.
- TestFlight distribution of a dev flavor is explicitly not covered: it would
  need a second App Store Connect app record, its own review cycle and its own
  IAP products. Related, Pro purchases cannot be exercised under a `.dev` id at
  all, because no App Store products exist behind it.
