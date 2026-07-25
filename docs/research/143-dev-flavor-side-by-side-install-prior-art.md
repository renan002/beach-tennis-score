# Research: how shipping iOS apps ship a "dev" build that installs side-by-side with the App Store build

> Serves the wayfinder map [#143](https://github.com/renan002/beach-tennis-score/issues/143)
> — installing a dev build alongside the App Store app.

**Question**: how do production iOS apps ship an internal/dev build that installs
alongside the App Store build on the same device, with isolated data — and what
does that mean for this repo (iOS + watchOS, XcodeGen, App Group, HealthKit on the
watch, SwiftData on the phone)?

**Scope**: read-only prior art. Nothing below has been applied to the repo. Repo state
referenced is worktree `grill-with-docs-61-7332b7` at `34d2171`.

**Source discipline**: every claim links to the source that owns it — Apple developer
documentation, Xcode Help, the XcodeGen `ProjectSpec.md`, or the actual
`.xcconfig`/`BUILD`/`project.yml` of a shipping open-source app. Claims marked
**[verified locally]** were proven by building *this project* (a copy in scratch) with
Xcode 26.6 (17F113) and inspecting the products — those are the strongest claims here.
Claims marked **[UNCONFIRMED]** could not be traced to a primary source; do not treat
them as settled.

---

## 0. Recommendation up front

**Use pattern (c) + (a): add a third build configuration `Dev` (a `debug` variant)
alongside `Debug`/`Release`, and drive every flavor-varying value off two build
settings (`BUNDLE_ID_SUFFIX`, `APP_NAME_SUFFIX`) set only in that config.** Do not
duplicate targets. Do not introduce `.xcconfig` files — `project.yml` already owns the
build settings, and XcodeGen's `settings.configs` expresses per-configuration values
natively.

Concretely, this exact diff was applied to a copy of `BeachTennisCounter/project.yml`,
regenerated with `xcodegen 2.45.4`, and built — **[verified locally]**:

```yaml
configs:
  Debug: debug
  Dev: debug
  Release: release

settings:
  base:
    SWIFT_VERSION: "6.0"
    MARKETING_VERSION: "1.3.1"
    CURRENT_PROJECT_VERSION: "7"
    BASE_BUNDLE_ID: com.renan.beachtennis
    BUNDLE_ID_SUFFIX: ""
    APP_NAME_SUFFIX: ""
  configs:
    Dev:
      BUNDLE_ID_SUFFIX: .dev
      APP_NAME_SUFFIX: " Dev"

targets:
  BeachTennisCounter:
    info:
      properties:
        CFBundleDisplayName: Beach Tennis Score$(APP_NAME_SUFFIX)
    entitlements:
      properties:
        com.apple.security.application-groups:
          - group.$(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)

  BeachTennisCounterWatch:
    info:
      properties:
        CFBundleDisplayName: Beach Tennis Score$(APP_NAME_SUFFIX)
        WKCompanionAppBundleIdentifier: $(PRODUCT_BUNDLE_IDENTIFIER:base)
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX).watchkitapp
```

Resolved output, per configuration **[verified locally]**:

| | Debug | Dev | Release |
|---|---|---|---|
| iOS `PRODUCT_BUNDLE_IDENTIFIER` | `com.renan.beachtennis` | `com.renan.beachtennis.dev` | `com.renan.beachtennis` |
| iOS `CFBundleDisplayName` (built app) | — | `Beach Tennis Score Dev` | — |
| iOS app-groups entitlement (built `.xcent`) | — | `group.com.renan.beachtennis.dev` | — |
| watch `CFBundleIdentifier` (built app) | — | `com.renan.beachtennis.dev.watchkitapp` | — |
| watch `WKCompanionAppBundleIdentifier` (built app) | — | `com.renan.beachtennis.dev` | — |
| watch entitlement (built `.xcent`) | — | `com.apple.developer.healthkit = true`, `application-identifier = <team>.com.renan.beachtennis.dev.watchkitapp` | — |

**The one thing this does not fix by itself**: `LiveStore.appGroupIdentifier` is a Swift
string literal (`BeachTennisCounter/iOS/Services/LiveStore.swift:8`). See §6.1 — this is
the highest-severity pitfall for this repo specifically.

---

## 1. The dominant real-world pattern

**Answer: (c)+(a) — extra build configurations, with the bundle id assembled from
per-configuration build settings — is what shipping apps actually do.** Duplicate
targets (b) is essentially absent from the large apps surveyed. Whether the settings
live in `.xcconfig` files (d) or directly in the project is a *storage* choice
orthogonal to the pattern, and the answer tracks the project's build tooling: hand-maintained
`.xcodeproj` → `.xcconfig`; generated project → the generator's own settings map.

### 1.1 Firefox iOS — configurations + one `.xcconfig` per flavor

`firefox-ios/Client.xcodeproj` carries build configurations named
`Fennec`, `FennecTesting`, `FirefoxBeta`, `FirefoxStaging`, `Firefox`, `Release` —
not just Debug/Release. Every target sets

```
PRODUCT_BUNDLE_IDENTIFIER = "$(MOZ_BUNDLE_ID)"
PRODUCT_BUNDLE_IDENTIFIER = "$(MOZ_BUNDLE_ID).$(PRODUCT_NAME)"   // extensions
```

and `MOZ_BUNDLE_ID` is defined once per flavor in a matching `.xcconfig`
([`Client/Configuration/Fennec.xcconfig`](https://github.com/mozilla-mobile/firefox-ios/blob/main/firefox-ios/Client/Configuration/Fennec.xcconfig),
[`Firefox.xcconfig`](https://github.com/mozilla-mobile/firefox-ios/blob/main/firefox-ios/Client/Configuration/Firefox.xcconfig),
[`FirefoxBeta.xcconfig`](https://github.com/mozilla-mobile/firefox-ios/blob/main/firefox-ios/Client/Configuration/FirefoxBeta.xcconfig)):

```
// Fennec.xcconfig               // Firefox.xcconfig
MOZ_BUNDLE_DISPLAY_NAME = Fennec ($(USER))
MOZ_BUNDLE_ID = org.mozilla.ios.Fennec
CODE_SIGN_ENTITLEMENTS = Client/Entitlements/FennecApplication.entitlements
CHANNEL = developer
```
```
MOZ_BUNDLE_DISPLAY_NAME = Firefox
MOZ_BUNDLE_ID = org.mozilla.ios.Firefox
CODE_SIGN_ENTITLEMENTS = Client/Entitlements/FirefoxApplication.entitlements
CHANNEL = release
```

Note two details worth stealing: the dev flavor's display name embeds `$(USER)`
("Fennec (renan)"), and the flavor also sets a Swift compilation condition
(`-DMOZ_CHANNEL_$(CHANNEL)`) so code can branch on channel. The app's
[`Client/Info.plist`](https://github.com/mozilla-mobile/firefox-ios/blob/main/firefox-ios/Client/Info.plist)
is a single shared file with `CFBundleDisplayName = $(MOZ_BUNDLE_DISPLAY_NAME)` and
`CFBundleIdentifier = $(PRODUCT_BUNDLE_IDENTIFIER)` — one Info.plist, many flavors.

Firefox uses a **separate entitlements file per flavor** rather than variable expansion,
because their per-flavor entitlements differ structurally, not just in string content
(`aps-environment` is `development` vs `production`, and only the release flavor carries
`com.apple.developer.applesignin` / `associated-domains`).

### 1.2 DuckDuckGo iOS — configurations + xcconfig variables expanded into entitlements

[`Configuration/DuckDuckGoDeveloper.xcconfig`](https://github.com/duckduckgo/iOS/blob/main/Configuration/DuckDuckGoDeveloper.xcconfig)
and [`Configuration/Configuration-Alpha.xcconfig`](https://github.com/duckduckgo/iOS/blob/main/Configuration/Configuration-Alpha.xcconfig)
define the same variable names with different values:

```
// default                             // Alpha
APP_ID = com.duckduckgo.mobile.ios     APP_ID = com.duckduckgo.mobile.ios.alpha
GROUP_ID_PREFIX = group.com.duckduckgo GROUP_ID_PREFIX = group.com.duckduckgo.alpha
SUBSCRIPTION_APP_GROUP = com.duckduckgo.subscriptions
                                       SUBSCRIPTION_APP_GROUP = com.duckduckgo.subscriptions.alpha
                                       VAULT_APP_GROUP = com.duckduckgo.vault.alpha
```

and `Configuration-Alpha.xcconfig` uses Xcode's `[config=Alpha]` conditional syntax,
confirming there is a build configuration literally named `Alpha`.

### 1.3 Telegram iOS — one bundle id variable, everything derived

Telegram's build takes `bundle_id` from a per-flavor JSON
([`build-system/appstore-configuration.json`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/build-system/appstore-configuration.json)
→ `"bundle_id": "ph.telegra.Telegraph"`; the internal flavor is
`org.telegram.TelegramInternal`) and derives every identifier from it inside
[`Telegram/BUILD`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/Telegram/BUILD):

```python
app_groups_fragment = """
    <string>group.{telegram_bundle_id}</string>
    ...
    <string>{telegram_team_id}.{telegram_bundle_id}</string>
"""
```

That is the cleanest statement of the principle: **one flavor knob, everything else
derived from it.**

### 1.4 Reasons teams cite

The reason duplicate targets lose is stated implicitly by all three: every one of them
has a *single* shared `Info.plist` and a *single* target per product, with the flavor
expressed as data. Duplicating targets duplicates the source list, the build phases, the
dependency graph and the scheme — and every future change has to be made N times.
Telegram states the derived-value motivation explicitly in a code comment next to the
watch app rule:

> "the watch Info.plist derives WKCompanionAppBundleIdentifier from it via
> `$(PRODUCT_BUNDLE_IDENTIFIER:base)`, so the embedded watch app is correct for any host
> (`ph.telegra.Telegraph`, `org.telegram.TelegramInternal`, …) **with no post-build plist
> patching**." — [`Telegram/BUILD`](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/Telegram/BUILD)

**[UNCONFIRMED]** I found no vendor engineering blog or ADR from these teams stating the
rationale in prose. The above is inferred from what their configuration files actually do.

---

## 2. Does an entitlements file expand build settings? Does Info.plist?

### 2.1 Info.plist — yes, and Apple's own docs rely on it

Apple's Info.plist key reference and Xcode's own templates use `$(...)` references
throughout; Apple's guidance for the bundle identifier is that the Info.plist should
*reference* the build setting:

> "The `INFOPLIST_FILE` build setting specifies the name of the `Info.plist` associated
> with your target. When building a target, Xcode reads this build setting and copies the
> referenced `Info.plist` into your application bundle. Because Xcode automatically
> processes the `Info.plist`…"
> — [QA1649, *About the Copy Bundle Resources Warning*](https://developer.apple.com/library/ios/qa/qa1649/_index.html)

**[verified locally]** Building this repo's iOS target in a `Dev` configuration produced
an installed `Info.plist` with `CFBundleIdentifier = com.renan.beachtennis.dev` and
`CFBundleDisplayName = Beach Tennis Score Dev`, from sources
`$(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)` and `Beach Tennis Score$(APP_NAME_SUFFIX)`.

`WKCompanionAppBundleIdentifier` is *not* special — it is an ordinary Info.plist string.
**[verified locally]** the watch app built with
`WKCompanionAppBundleIdentifier: $(PRODUCT_BUNDLE_IDENTIFIER:base)` yielded
`com.renan.beachtennis.dev` in the built `Info.plist` (the `:base` string operator strips
the trailing `.watchkitapp`), exactly as Telegram describes.

Caveat: this is plain build-setting expansion, which is *distinct from* C-preprocessor
Info.plist preprocessing (`INFOPLIST_PREPROCESS`, documented in
[TN2175](https://developer.apple.com/library/archive/technotes/tn2175/_index.html)).
Leave `INFOPLIST_PREPROCESS` off; expansion works without it.

### 2.2 Entitlements — yes in practice, but Apple never says so plainly

**There is no Apple sentence that says "build settings are expanded in your entitlements
plist."** [TN2415 *Entitlements Troubleshooting*](https://developer.apple.com/library/archive/technotes/tn2415/_index.html)
only covers the different mechanism of wildcard filling:

> "When Xcode creates the entitlements for the app's signature, values from the code
> signing entitlements file are used to fill in any wildcard, asterisk portions of the
> entitlements that might exist in the code signing provisioning profile."

So the primary-source position is: **[UNCONFIRMED] by Apple prose**. But it is confirmed
three other ways:

1. **Apple's own project templates ship entitlements with `$(…)` in them.** e.g.
   `/Applications/Xcode.app/Contents/Developer/Library/Xcode/Templates/Project Templates/MultiPlatform/Application/iOS Foveated Streaming App.xctemplate/iOS-App.Entitlements`:
   ```xml
   <key>keychain-access-groups</key>
   <array><string>$(AppIdentifierPrefix)com.apple.StreamingSessionApp-iOS</string></array>
   ```
2. **A shipping app relies on it for App Groups specifically.**
   [`DuckDuckGo/DuckDuckGo.entitlements`](https://github.com/duckduckgo/iOS/blob/main/DuckDuckGo/DuckDuckGo.entitlements):
   ```xml
   <key>com.apple.security.application-groups</key>
   <array>
     <string>$(GROUP_ID_PREFIX).bookmarks</string>
     <string>$(GROUP_ID_PREFIX).database</string>
     …
   </array>
   <key>keychain-access-groups</key>
   <array>
     <string>$(AppIdentifierPrefix)$(VAULT_APP_GROUP)</string>
     <string>$(AppIdentifierPrefix)$(APP_ID)</string>
   </array>
   ```
   `GROUP_ID_PREFIX`, `VAULT_APP_GROUP` and `APP_ID` are ordinary xcconfig build settings
   from `Configuration-Alpha.xcconfig` above — not Apple-provided provisioning variables.
3. **[verified locally]** — the decisive one. With
   `<string>group.$(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)</string>` in
   `iOS/BeachTennisCounter.entitlements`, the generated
   `…/Dev-iphonesimulator/BeachTennisCounter.build/BeachTennisCounter.app-Simulated.xcent`
   contained:
   ```
   "application-identifier" => "CU54PVDRHC.com.renan.beachtennis.dev"
   "com.apple.security.application-groups" => [ 0 => "group.com.renan.beachtennis.dev" ]
   ```

Mechanism note, for whoever has to debug this later: the entitlements that get signed are
assembled by the provisioning subsystem and handed to the build as an already-merged
property list — see `constructProductEntitlementsTasks` in
[`Sources/SWBCore/SpecImplementations/Tools/ProductPackaging.swift`](https://github.com/swiftlang/swift-build/blob/main/Sources/SWBCore/SpecImplementations/Tools/ProductPackaging.swift)
(`var entitlements = provisioningTaskInputs.entitlements(for: entitlementsVariant)`), and
[`ProcessProductEntitlementsTaskAction.swift`](https://github.com/swiftlang/swift-build/blob/main/Sources/SWBTaskExecution/TaskActions/ProcessProductEntitlementsTaskAction.swift)
does no macro evaluation of its own. The expansion happens upstream of the open-source
build system, in the (closed) provisioning layer. That is why there is no public spec for
it — and why the empirical check above matters more than any doc would.

Practical consequence: **prefer variable expansion for values that differ only as strings
(the App Group id), and prefer a separate entitlements file per flavor if the *set of
keys* differs** (Firefox's `aps-environment` case). We only have the former.

---

## 3. watchOS: what must hold between the iOS app and the embedded watch app

The rule is stated in Apple's Info.plist Key Reference:

> "Apart from the addition of the `.watchkitapp` string, the bundle identifier of the
> Watch app must match the bundle identifier of the iOS app. (The bundle identifier of
> the WatchKit extension must also be based on the bundle identifier of the iOS app.)
> **The system does not launch a Watch app whose bundle identifier does not match the
> bundle identifier of its WatchKit extension or iOS app.**"
> — [*watchOS Keys*, Information Property List Key Reference](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/watchOSKeys.html)

and for the key itself:

> "`WKCompanionAppBundleIdentifier` (String – watchOS) specifies the bundle identifier of
> the iOS app with which the Watch app is paired. Xcode adds this key to your Watch app's
> `Info.plist` file automatically."
> — same page; see also
> [WKCompanionAppBundleIdentifier](https://developer.apple.com/documentation/bundleresources/information-property-list/wkcompanionappbundleidentifier)

So for a flavored build **all three must move together**:

| | App Store | Dev |
|---|---|---|
| iOS `PRODUCT_BUNDLE_IDENTIFIER` | `com.renan.beachtennis` | `com.renan.beachtennis.dev` |
| watch `PRODUCT_BUNDLE_IDENTIFIER` | `com.renan.beachtennis.watchkitapp` | `com.renan.beachtennis.dev.watchkitapp` |
| watch `WKCompanionAppBundleIdentifier` | `com.renan.beachtennis` | `com.renan.beachtennis.dev` |

**Two caveats, stated honestly:**

- That page is **archived** Apple documentation from the WatchKit-extension era (watchOS
  1/2). This project uses the modern single-target watch app (`WKApplication: true`, no
  extension). **[UNCONFIRMED]**: I could not find a *current* Apple page that restates the
  `.watchkitapp` suffix requirement for single-target watch apps. What I can say is
  (a) the archived doc is the only Apple statement on the topic, (b) Telegram's shipping
  build derives `"{bundle_id}.watchkitapp"` from the host id for both its App Store and
  internal flavors, and (c) **[verified locally]** the suffixed pair builds and signs
  cleanly. Treat the suffix as required.
- `WKRunsIndependentlyOfCompanionApp: true` is already set on this project's watch target,
  so the watch app can install standalone — but that does not exempt it from the id rule,
  because `WKCompanionAppBundleIdentifier` is still present and still names a companion.

Deriving the companion id as `$(PRODUCT_BUNDLE_IDENTIFIER:base)` (Telegram's trick,
**[verified locally]** here) is preferable to repeating `$(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)`
— it makes the two ids structurally impossible to drift apart.

---

## 4. App Groups: shared or per-flavor?

**Nothing forces a separate group per flavor. Everything about the goal ("isolated data")
does.**

What Apple enforces:

> "App groups allow multiple apps produced by a single development team to access shared
> containers and keychain access groups… Apps may belong to one or more app groups."
> — [App Groups Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups)

> "You need to register app groups for iOS, iPadOS, tvOS, visionOS, and watchOS apps…
> Each developer account can register a maximum of 1,000 app groups." … "Container IDs
> must begin with `group.` followed by a custom string."
> — [Configuring app groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)

So two flavors of the same app, on the same team, *may* legally share `group.com.renan.beachtennis`
— the group is registered to the team, not to a bundle id. If they share it, they share the
SwiftData store, which defeats the purpose.

Prior art is unanimous on separating: DuckDuckGo's Alpha flavor uses
`group.com.duckduckgo.alpha` vs `group.com.duckduckgo`; Firefox's Fennec entitlement lists
`group.org.mozilla.ios.Fennec` vs `group.org.mozilla.ios.Firefox`; Telegram derives
`group.{bundle_id}` mechanically. **Register `group.com.renan.beachtennis.dev` as a second
App Group.** (Note the `.dev` suffix lands *after* the whole base id, so the group id
mirrors the bundle id — that is what makes the single `$(BUNDLE_ID_SUFFIX)` knob work.)

---

## 5. Per-flavor app icons

**The Apple-supported mechanism is a second app icon set in the same asset catalog,
selected per build configuration via the "Primary App Icon Set Name" build setting
(`ASSETCATALOG_COMPILER_APPICON_NAME`).** Apple says so directly:

> "You can specialize the app icon for the Debug and Release configurations by modifying
> the **Primary App Icon Set Name** build setting in the Build Settings tab."
> …
> "If you don't select the Include all app icon assets option, Xcode only includes the app
> icon set you specify in the App Icons Source pop-up menu when it builds your app. You
> might leave this option unselected if you want to use a different icon for the Debug and
> Release builds of your app without including the Debug icon in your Release app bundle."
> — [Configuring your app icon](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)

Firefox iOS does exactly this — its `project.pbxproj` contains
`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`, `= AppIcon_Beta` and `= AppIcon_Developer`
across its flavor configurations
([Client.xcodeproj](https://github.com/mozilla-mobile/firefox-ios/blob/main/firefox-ios/Client.xcodeproj/project.pbxproj)).

In XcodeGen this is one line per config:

```yaml
    settings:
      base:
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
      configs:
        Dev:
          ASSETCATALOG_COMPILER_APPICON_NAME: AppIconDev
```

Two mechanisms to *not* reach for:

- **Alternate app icons** (`setAlternateIconName(_:)` / the `Alternate App Icon Sets`
  build setting, same Apple page) are a *runtime* user-facing feature — the user picks an
  icon inside the app. Wrong tool for a build flavor: it ships both icons in every build
  and requires code to switch.
- **Build-phase icon post-processing** (a script that overlays a "DEV" ribbon on the PNGs
  after compilation) appears in the wild but is not an Apple-supported mechanism and
  breaks with `.icon`/Icon Composer assets. None of the three shipping apps surveyed does
  it. **[UNCONFIRMED]** whether any large app still does — I found no primary example.

**[UNCONFIRMED]**: I could not retrieve the Human Interface Guidelines "App icons" page
content (it is JavaScript-rendered and WebFetch returned only the title), so I cannot
quote HIG guidance on alternate icons. Nothing in the recommendation depends on it.

Note this repo generates its icon from `BeachTennisCounter/icon-source.svg`; a `Dev`
variant means one more generated icon set, not a new pipeline.

---

## 6. Pitfalls

### 6.1 **The App Group id is hardcoded in Swift — this repo's biggest one**

`BeachTennisCounter/iOS/Services/LiveStore.swift:8`:

```swift
static let appGroupIdentifier = "group.com.renan.beachtennis"
```

and `LiveStore.directory` resolves the SwiftData store through
`FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`. Flavoring only
the *entitlement* leaves this literal pointing at the release group. Two bad outcomes,
both silent:

- If the Dev build's entitlement is `group.…dev` but the code asks for
  `group.com.renan.beachtennis`, `containerURL(forSecurityApplicationGroupIdentifier:)`
  returns `nil` and the existing fallback in `LiveStore.directory` quietly relocates the
  store to `.applicationSupportDirectory`. The app works; the store is somewhere else than
  the comment in that file claims; the recovery/restore paths (#43, #48) now act on a
  different directory than intended.
- If the group is *not* flavored, both flavors share one store — the dev build can corrupt
  or migrate the real Match History.

Fix: make the constant flavor-derived rather than literal. Since Info.plist expansion is
**[verified locally]**, the cheapest correct shape is to publish the group id as an
Info.plist key (`AppGroupIdentifier: group.$(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)`) and read
it with `Bundle.main.object(forInfoDictionaryKey:)`, so entitlement and code cannot drift.
Whatever is chosen, it needs a test — the current tests construct their own
`ModelConfiguration(url:)` and never exercise the group lookup.

### 6.2 HealthKit and App Group must be provisioned for the *new* App IDs

`com.renan.beachtennis.dev.watchkitapp` is a brand-new App ID with no capabilities. The
HealthKit entitlement on the watch target will fail to sign for a device until HealthKit
is enabled on that App ID, and the App Group entitlement fails until
`group.com.renan.beachtennis.dev` is registered *and* attached to both new App IDs.
Apple's capability flow:

> "Before you can use HealthKit, you must enable the HealthKit capabilities for your app.
> In Xcode, select the project and add the HealthKit capability."
> — [Setting up HealthKit](https://developer.apple.com/documentation/healthkit/setting-up-healthkit)

> "Xcode automatically includes the enabled entitlement key and value pair in your app's
> entitlements file… Xcode also automatically creates new provisioning profiles with the
> new entitlements." — but — "While you can enable all managed capabilities in Xcode,
> you'll be prompted to manually update your entitlements file with the correct values for
> some managed capabilities."
> — [Provisioning with managed capabilities](https://developer.apple.com/help/account/reference/provisioning-with-managed-capabilities)

Simulator builds hide all of this: **[verified locally]** the `Dev` simulator build signed
fine with an empty real `.xcent` and a fully-populated `-Simulated.xcent`, because
simulator entitlements are not enforced against a profile. **The first real signal comes
from a device build.** Plan to do one before declaring this done.

**[UNCONFIRMED]**: whether Xcode's automatic signing silently *registers* the two new App
IDs on first device build, or errors and requires registering them in the developer
portal first. Xcode Help says only "If you use automatic signing (recommended), Xcode
creates these development signing assets for you when you need them"
([Signing & Capabilities workflow](https://help.apple.com/xcode/mac/current/en.lproj/dev60b6fbbc7.html));
it does not name App IDs. Secondary sources assert Xcode auto-creates the App ID. Do not
rely on it — check the portal after the first device build.

Also relevant if the iOS app ever gains HealthKit:

> "When you enable the HealthKit capabilities on an iOS app, Xcode adds HealthKit to the
> list of required device capabilities… The `healthkit` entry isn't used by watchOS apps."
> — [Setting up HealthKit](https://developer.apple.com/documentation/healthkit/setting-up-healthkit)

### 6.3 XcodeGen's `settings.configs` key matching is substring-based

This is a real footgun and it is documented:

> "**configs**: Mapping of config name to a settings spec. These settings will only be
> applied for that config. **Each key will be matched to any configs that contain the key
> and is case insensitive.** So if you had `Staging Debug` and `Staging Release`, you could
> apply settings to both of them using `staging`. However if a config name is an exact
> match to a config it won't be applied to any others. eg `Release` will be applied to
> config `Release` but not `Staging Release`"
> — [XcodeGen ProjectSpec.md § Settings](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md#settings)

A config named `Dev` is an exact match for the key `Dev`, so it is safe — but do **not**
name it `Debug Dev` or add a key `Dev` while a config `Development` exists.

Related spec facts to lean on:

> "Each config maps to a build type of either `debug` or `release` which will then apply
> default `Build Settings` to the project… If no configs are specified, default `Debug`
> and `Release` configs will be created automatically."
> — [ProjectSpec.md § Configs](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md#configs)

```yaml
configs:
  Debug: debug
  Beta: release
  AppStore: release
```

> "**defaultConfig**: The default configuration for command line builds from Xcode. If the
> configuration provided here doesn't match one in your configs key, XcodeGen will fail.
> If you don't set this, the first configuration alphabetically will be chosen."
> — [ProjectSpec.md § Options](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md#options)

That last one bites: with configs `Debug`/`Dev`/`Release`, "first alphabetically" is
`Debug` — fine today, but adding an `Alpha` config would silently change the CLI default.
Set `options.defaultConfig` explicitly if a third config lands.

XcodeGen also offers `configVariants` for auto-generating a scheme per flavor
([ProjectSpec.md § Target Scheme](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md#target-scheme)) —
worth knowing, but with one extra flavor an explicit second scheme is clearer.

### 6.4 Schemes and CI

The moment a third configuration exists, every scheme action that names a config must be
audited. This repo's schemes pin `run: config: Debug`, `test: config: Debug`,
`archive: config: Release` (`project.yml:113-122`). A Dev flavor needs its own scheme
(`run/test: Dev`, and `archive: Dev` if it is ever distributed via TestFlight/ad-hoc), or
the Dev config is unreachable from Xcode.

CI (`.github/workflows/ci.yml`) runs the test scheme on `Debug`. Adding a config does not
change that, but if the Dev flavor is meant to be *built* in CI it is a second job — and
the combined iOS+watchOS CLI build limitation noted in `CLAUDE.md` still applies.
**[verified locally]**: building the app scheme with `-sdk iphonesimulator` fails on the
watch target's asset catalog (`The stickers icon set, app icon set, or icon stack named
"AppIcon" did not have any applicable content`) — this is the pre-existing CLI limitation,
not something the flavor introduces; the two targets built fine when built separately with
their own SDKs.

### 6.5 App Store Connect / distribution

A flavored bundle id is a *different app* to App Store Connect. `com.renan.beachtennis.dev`
cannot be uploaded to the existing app record, and cannot use the existing TestFlight
group. If the Dev flavor is only ever installed from Xcode onto your own device, this
never comes up — decide that up front, because it changes whether the Dev config needs a
distribution-capable archive path at all.

### 6.6 Watch-specific breakage to watch for

- Both flavors installed means **two watch apps** on the Watch, with identical display
  names unless `CFBundleDisplayName` is also flavored. Flavor the display name (§0 does).
- WatchConnectivity pairs by companion bundle id, so the Dev watch app talks only to the
  Dev phone app — which is the desired isolation, but it also means an existing paired
  release watch app will not receive Dev match results. Expect to re-run the
  watch→phone verification (`verify-watch-sim-calibration`) against the Dev pair rather
  than assuming the release pairing carries over.
- `WKRunsIndependentlyOfCompanionApp: true` means the Dev watch app can be installed
  without its phone app; do not read a successful watch install as proof the pairing is
  right. Check `WKCompanionAppBundleIdentifier` in the built product (as done above).

### 6.7 `xcodegen generate` hygiene

No new `.swift` files are involved, but `configs:` is a structural change — regenerate
(`cd BeachTennisCounter && xcodegen generate`) and commit the resulting `.xcodeproj` in
the same commit, per `CLAUDE.md`. Xcode will not learn about a new configuration otherwise.

---

## 7. What was verified, and how

All **[verified locally]** claims come from one experiment: `BeachTennisCounter/` was
copied to a scratch directory, `project.yml` patched exactly as shown in §0, regenerated
with `xcodegen 2.45.4`, and built with Xcode 26.6 (17F113):

```
xcodebuild -scheme BeachTennisCounter      -configuration Dev -sdk iphonesimulator   build   # BUILD SUCCEEDED
xcodebuild -scheme BeachTennisCounterWatch -configuration Dev -sdk watchsimulator    build   # BUILD SUCCEEDED
```

then inspecting `Info.plist` (`plutil -extract`), the generated `.xcent` files, and
`xcodebuild -showBuildSettings` across all three configurations. The scratch copy is
throwaway; **no file in the repo was modified by this research.**
