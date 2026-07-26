# Feature flags are compilation conditions set per build configuration

Pro is finished — the purchase surface, the entitlement, and all three gates of
ADR 0004 — but it is not for sale. It ships **dark**: `Release` builds have no
purchase affordance anywhere and every Pro feature is free to everybody, which
is exactly the behaviour of the releases before Pro existed. That let Pro be
built and merged across several releases without deciding when to sell it.

**A feature flag here is a Swift compilation condition, defined per build
configuration in `project.yml`.** `PRO_ON_SALE` is defined on `Debug` and `Dev`
and *absent* from `Release`; `FeatureFlags.proOnSale` reads it. Switching a flag
on means editing `project.yml`, running `xcodegen generate`, and cutting a
release. There is nothing to flip in a build a user already has, and nothing to
flip for a subset of users.

That constraint is the point, and it is why no hosted flag service was
considered on its merits. App Store guideline **2.5.2** forbids downloading code
that "introduces or changes features"; guideline **2.1(b)** separately expects a
reviewer to be able to reach a configured in-app purchase, which is why the IAP
record stays in *Prepare for Submission* while the app is dark rather than being
live-but-unreachable. A remote flag service would be the shape that has to argue
it is compliant. A compilation condition never has to. Full findings:
[`docs/research/168-dark-iap-app-store-review.md`](../research/168-dark-iap-app-store-review.md).

The mechanism therefore rules out, permanently and by construction: remote
config, staged or percentage rollout, kill switches, and A/B experimentation.
Anything wanting those is not a feature flag in this project's sense.

## The three rules the mechanism actually rests on

**One `#if`, in one file.** `iOS/FeatureFlags.swift` holds it. Every consumer
reads a plain `Bool` and branches with an ordinary `if`, so both states are code
the compiler always checks and tests can always reach. This matters almost
entirely for the *off* state: `Release` is the one configuration nobody runs
locally, and under `#if` the dark path would be text the developer's compiler
never sees. `PRO_ON_SALE` is spelled in `project.yml` and in that one file, and
nowhere else.

**Gates read the entitlement, never the flag.** `ProEntitlement` splits into
`ownsPro` — what StoreKit says, the truthful reading — and a derived
`isPro = ownsPro || !proOnSale`, "you own it, *or* it isn't for sale". All three
Pro gates are plain `isPro` branches that never mention `FeatureFlags`, so the
flag has exactly three consumers, one line each: that derivation, the guard in
`ProEntitlement.start()`, and the purchase section in `SettingsView`. The rule
behind `isPro` is a pure `isPro(ownsPro:proOnSale:)`, which is what makes the
dark answer testable from a `Debug` bundle.

**Off means the previous behaviour, exactly.** A dark build makes zero App Store
traffic — `start()` returns immediately, so no product fetch, no entitlement
read, no `Transaction.updates` listener — Settings runs Appearance straight into
About, Estatísticas is open, Vários is selectable, and every Cartão is
watermarked. The accepted cost is that `ownsPro` stays `false` for the whole dark
period, so nothing in a shipped build can tell who has paid; nobody has.

## Why the flag cannot ship wrong

`Release` defining no compilation conditions at all is the darkness — an absence,
not a false value — and an absence is easy to add to by accident and impossible
to notice by reading a diff of `project.pbxproj`. Two things watch it:

- `ProEntitlementTests` asserts the wiring from the checked-in `project.pbxproj`:
  `Debug` and `Dev` define `PRO_ON_SALE`, `Release` defines nothing.
- `scripts/validate-release-is-dark.sh` asserts the same from a dedicated,
  unconditional CI job, **`release-is-dark`** — the check required on `main`,
  since merging to `main` is what triggers the build. It walks *every* build
  configuration block, because a flag set on the app target alone ships just as
  surely, and it fails loudly if it can no longer find what it walks.

The overlap is deliberate. The unit suite is a 45-minute macOS job that skips
steps on non-app changes, so it is the wrong thing to require as the gate on a
release merge.

There is **no bypass flag**. The guard is deleted — script, test, and CI job — in
the same diff that flips the flag, because a permanent escape hatch guarding a
one-time event is a permanent hole. The procedure for that day, including the
step that will otherwise lock the flip PR out of merging, is
[`docs/pro-switch-on-checklist.md`](../pro-switch-on-checklist.md).

## Consequences

- **Nothing in this repository builds the binary.** Archives and TestFlight
  uploads come from **Xcode Cloud**, triggered by a merge to `main`; its workflow
  — scheme, configuration, environment, custom build settings — lives entirely in
  App Store Connect, with no `ci_scripts/` and no trace here. Whether a shipped
  binary is dark depends on which configuration Xcode Cloud archives, and that
  fact is *unreadable from inside this repo*. Reading `project.yml` alone tells
  you `Release` is dark, not that `Release` is what ships. This is also why the
  guard must be required on the release PR into `main` rather than on the build:
  no repo-side check can see the Xcode Cloud side.
- **Pro goes unexercised by anyone but a developer at a Mac for the whole dark
  period.** A flag-on TestFlight build was rejected: it would exercise a shape
  that never ships, and producing one needs exactly the archive capability the
  guard forbids. Pro's real testing happens once, on the switch-on release's
  TestFlight build, before submission — which is why the checklist makes that a
  step and not an afterthought.
- **Switching on takes features away.** Users on 1.4/1.5 have Estatísticas and
  Vários for free and lose them at the flip. Accepted when Pro was scoped, and it
  is the reason `PhoneSessionManager` reports an *effective* sport setting rather
  than gating the picker alone — a stored `multiple` would otherwise have kept
  Vários forever for exactly that population. Storage is never rewritten, so
  buying Pro hands the choice straight back. The switch-on release's notes say so
  plainly; no dark release pre-announces it.
- **`FeatureFlags` lives in `iOS/`, not `Shared/`.** `Shared/` compiles into the
  watch target, which links no StoreKit and shows no purchase UI (ADR 0004). A
  genuinely watch-side flag would move the file.
- **Setting `SWIFT_ACTIVE_COMPILATION_CONDITIONS` replaces XcodeGen's automatic
  value** for a debug-type configuration rather than adding to it, so `DEBUG` had
  to be restated on `Debug` and `Dev`. Forgetting it silently turns `#if DEBUG`
  off across the whole project.
- The flag varies along a **different axis than the dev flavor** (ADR 0007):
  flavoring splits `Dev` from `Debug` + `Release`, while this splits `Release`
  from `Debug` + `Dev`. Both are per-configuration settings in the same
  `configs:` block, and a new configuration must be considered against both
  axes — it is not enough to copy one row.
