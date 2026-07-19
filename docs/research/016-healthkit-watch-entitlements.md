# Research: HealthKit entitlements/plist/privacy changes for `BeachTennisCounterWatch` (plan 016 spike, ticket #64)

**Question**: What exactly must the `BeachTennisCounterWatch` target gain to run an
`HKWorkoutSession` + `HKLiveWorkoutBuilder`, stated as the concrete
`project.yml`/plist changes a build plan would make?

**Scope**: design-only research. Nothing below has been applied; the snippets are
what a build plan would lift verbatim. All claims cite Apple primary sources or
XcodeGen's official spec. Repo state referenced is worktree
`worktree-quirky-questing-meerkat` at `f4bc924`.

---

## 1. Changes a build plan would make

### 1a. `BeachTennisCounter/project.yml` — add an `entitlements:` block to the watch target

The watch target (`project.yml:67-89`) has no `entitlements:` block today. Add one
mirroring the iOS target's shape (`project.yml:53-57`), between `sources:` and
`info:` (position is cosmetic; sibling key of `info`/`settings`):

```yaml
  BeachTennisCounterWatch:
    type: application
    platform: watchOS
    deploymentTarget: "26.0"
    sources:
      - path: watchOS
      - path: Shared
    entitlements:                                    # NEW
      path: watchOS/BeachTennisCounterWatch.entitlements
      properties:
        com.apple.developer.healthkit: true
    info:
      ...
```

XcodeGen semantics: "If defined this will generate and write a `.entitlements`
file, and use it by setting `CODE_SIGN_ENTITLEMENTS` build setting for every
configuration. All properties must be provided" — so the `.entitlements` file is
**generated** by `xcodegen generate`, not hand-created, exactly as
`iOS/BeachTennisCounter.entitlements` is today.
Source: XcodeGen ProjectSpec, "Target → entitlements" —
<https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md#entitlements>

Entitlement key facts:

- `com.apple.developer.healthkit` — "A Boolean value that indicates whether the
  app may request user authorization to access health and activity data that
  appears in the Health app." Value is boolean `true`. "To add this entitlement
  to your app, enable the HealthKit capability in Xcode" (XcodeGen replaces the
  Xcode UI step by writing the same key into the generated entitlements file).
  Source: <https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.healthkit>
- `com.apple.developer.healthkit.access` is **not needed**. It exists only for
  "Health data types that require additional permission" — i.e. FHIR-backed
  clinical health records (`health-records` value). Heart rate + workout types are
  ordinary HealthKit types covered by the base entitlement: "The [HealthKit
  entitlement] provides access to most HealthKit data types. However, because of
  their highly sensitive nature, some data types require additional
  entitlements." Enabling Clinical Health Records without using it is itself a
  rejection risk ("App Review may reject apps that enable the Clinical Health
  Records capability if the app doesn't actually use the health record data").
  Sources: <https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.healthkit.access>,
  <https://developer.apple.com/documentation/healthkit/setting-up-healthkit> ("Enable HealthKit" section)
- `com.apple.developer.healthkit.background-delivery` is **not needed** either —
  it only gates background delivery for `HKObserverQuery` updates
  (`enableBackgroundDelivery(for:frequency:)`), which is unrelated to a live
  `HKWorkoutSession`.
  Source: <https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.healthkit.background-delivery>
- The **iOS companion target's entitlements stay unchanged** — only the watch
  binary calls HealthKit in this design (see §3 for why the usage strings also
  stay watch-side).

### 1b. `project.yml` — add `WKBackgroundModes` to the watch target's `info.properties`

```yaml
    info:
      path: watchOS/Info.plist
      properties:
        CFBundleName: BeachTennisWatch
        CFBundleDisplayName: Beach Tennis Score
        CFBundleShortVersionString: "$(MARKETING_VERSION)"
        CFBundleVersion: "$(CURRENT_PROJECT_VERSION)"
        ITSAppUsesNonExemptEncryption: false
        WKCompanionAppBundleIdentifier: com.renan.beachtennis
        WKApplication: true
        WKRunsIndependentlyOfCompanionApp: true
        WKBackgroundModes:                           # NEW
          - workout-processing
        NSHealthShareUsageDescription: >-            # NEW — see §1c for wording rules
          Beach Tennis Score reads your heart rate during a match to show live
          workout stats.
        NSHealthUpdateUsageDescription: >-           # NEW
          Beach Tennis Score saves each match as a workout in the Health app so
          you get activity credit.
```

The generated `watchOS/Info.plist` fragment this produces:

```xml
<key>WKBackgroundModes</key>
<array>
    <string>workout-processing</string>
</array>
<key>NSHealthShareUsageDescription</key>
<string>Beach Tennis Score reads your heart rate during a match to show live workout stats.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Beach Tennis Score saves each match as a workout in the Health app so you get activity credit.</string>
```

(XcodeGen `info.properties` generates the Info.plist and sets `INFOPLIST_FILE`;
this target already uses that mechanism. Source: XcodeGen ProjectSpec, "Target →
info" — <https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md#info>)

### 1c. pt-BR localization of the two usage strings — per-target `InfoPlist.strings`

This repo localizes Info.plist values via per-target `InfoPlist.strings`, **not**
the String Catalog (`Shared/Localizable.xcstrings` is UI strings only; CLAUDE.md:
"`InfoPlist.strings` is separate and still per-target"). The watch file already
exists with one key:

`BeachTennisCounter/watchOS/pt-BR.lproj/InfoPlist.strings` (current content is a
single `CFBundleDisplayName` line). A build plan appends:

```
NSHealthShareUsageDescription = "O Placar Beach Tennis lê sua frequência cardíaca durante a partida para mostrar estatísticas do treino.";
NSHealthUpdateUsageDescription = "O Placar Beach Tennis salva cada partida como um treino no app Saúde para você ganhar crédito de atividade.";
```

No `project.yml` change is needed for this — the `.lproj` directory sits inside
the `watchOS` sources path and XcodeGen "parses `.lproj` files appropriately"
into variant groups; `pt-BR` is already in `knownRegions` (`project.yml:10-13`).
No English `en.lproj/InfoPlist.strings` is needed: English is the development
language, so the `info.properties` values are the source strings.

### 1d. `watchOS/PrivacyInfo.xcprivacy` — **no change required**

The watch privacy manifest already exists
(`BeachTennisCounter/watchOS/PrivacyInfo.xcprivacy`, added alongside plan 013's
iOS work; both files currently declare only
`NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1` with empty
`NSPrivacyCollectedDataTypes`). HealthKit requires nothing new in it — see §4 for
the two-part justification (not a required-reason API; on-device data is not
"collected"). If the build plan wants the file to be self-documenting it may
leave a comment, but no key changes.

### 1e. Non-file changes the build plan must note

- **App ID capability / signing**: the HealthKit entitlement must be reflected in
  the provisioning profile. With Xcode's default **automatic signing**, adding
  the capability/entitlement is enough — "Xcode may edit the [entitlements] and
  [Info.plist] files, add related frameworks, and configure your signing assets";
  "Use the default automatic signing… If you manually sign your app, you need to
  perform the capability configuration steps yourself."
  Source: <https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app>
- **No paid-membership blocker** (a STOP condition in plan 016 that does NOT
  trigger): Apple's supported-capabilities table lists HealthKit as available to
  ADP, ADEP, **and** free "Apple Developer" accounts.
  Source: <https://developer.apple.com/help/account/reference/supported-capabilities-ios/>
- **CI is unaffected**: the CI test job builds with `CODE_SIGNING_ALLOWED=NO`, so
  the new entitlement never hits provisioning in CI.
- **No `UIRequiredDeviceCapabilities` concern**: Xcode adds a `healthkit`
  required-device-capability entry only when enabling the capability **on an iOS
  app**, and "The `healthkit` entry isn't used by watchOS apps." Since only the
  watch target gains the entitlement (and XcodeGen writes plists explicitly
  anyway), nothing to add or strip.
  Source: <https://developer.apple.com/documentation/healthkit/setting-up-healthkit>

---

## 2. Supporting findings

### 2.1 Entitlement (§1a)

Covered above. One documentation quirk worth recording: the entitlement page's
platform-availability metadata lists iOS/iPadOS/visionOS but not watchOS, yet the
same key is what the Xcode HealthKit capability writes for watchOS targets, and
watch-facing HealthKit docs ("Setting up HealthKit", "Running workout sessions")
unconditionally require enabling the HealthKit capability for the app that calls
HealthKit — which here is the watch app. The sibling entitlement
`com.apple.developer.healthkit.background-delivery` explicitly lists watchOS 8.0+,
confirming the entitlement family applies on watchOS. Do not read the metadata
omission as "no entitlement needed on watchOS".

### 2.2 `WKBackgroundModes: workout-processing` (§1b) — required, not optional

- `WKBackgroundModes` is "The services a watchOS app provides that require it to
  continue running in the background"; the `workout-processing` value "Allows an
  active workout session to run in the background." An extended-runtime mode and
  `workout-processing` may coexist, but nothing else is needed here.
  Source: <https://developer.apple.com/documentation/bundleresources/information-property-list/wkbackgroundmodes>
- Is it required for `HKWorkoutSession` at all, or only for background runtime?
  Apple's "Running workout sessions" (the canonical HKWorkoutSession +
  HKLiveWorkoutBuilder guide) states it as a requirement of the session path:
  "Apps with an active workout session can run in the background, so you need to
  add the background modes capability to your WatchKit App Extension. **Workout
  sessions require the Workout processing background mode.**" Since the entire
  point of plan 016 includes keeping the app alive for the match duration, treat
  it as mandatory.
  Source: <https://developer.apple.com/documentation/healthkit/running-workout-sessions> ("Enable background mode")
- Background Modes is a plist-only capability (no App ID/provisioning component);
  Xcode's Signing & Capabilities tab merely "ensures that these values are set
  properly" — setting the key via `info.properties` is equivalent.
  Source: same WKBackgroundModes page.
- Not needed: the Audio background mode (only "If your app plays audio or
  provides haptic feedback **during the workout session**" via long-form audio;
  the app's `WKInterfaceDevice.play(.click)` haptics are fired by foreground
  taps, and no audio is played). If a later feature adds in-workout audio cues,
  revisit. Source: same "Running workout sessions" page.

### 2.3 Usage description strings (§1b/1c) — both keys, on the **watch** target

- `NSHealthShareUsageDescription`: "A message that explains to people why the app
  requests permission to **read** samples from the HealthKit store. … This key is
  required if your app uses APIs that access someone's health data."
  <https://developer.apple.com/documentation/bundleresources/information-property-list/nshealthshareusagedescription>
- `NSHealthUpdateUsageDescription`: "A message to the user that explains why the
  app requested permission to **save** samples to the HealthKit store. … This key
  is required if your app uses APIs that update the user's health data."
  <https://developer.apple.com/documentation/bundleresources/information-property-list/nshealthupdateusagedescription>
- The planned feature both **reads** (heart rate, active energy delivered live by
  the `HKLiveWorkoutBuilder` data source) and **writes** (saves the finished
  `HKWorkout`), so **both keys are required**. "For workout sessions, you must
  request permission to share workout types. You may also want to read any data
  types automatically recorded by Apple Watch as part of the session."
  Source: <https://developer.apple.com/documentation/healthkit/running-workout-sessions> ("Request authorization")
- **Where they live**: on the target that shows the authorization sheet — the
  watch app. "In watchOS 6 and later, users can authorize reading and sharing
  data on Apple Watch. As a result, you must add usage descriptions to your
  WatchKit App Extension." (In a modern single-target watch app — this repo's
  `WKApplication: true` layout — the "extension" Info.plist *is* the watch app's
  Info.plist, generated from the watch target's `info.properties`.) "Authorizing
  access to health data" repeats: "Xcode requires separate custom messages for
  reading and writing HealthKit data. Set the [NSHealthShareUsageDescription] key
  … and the [NSHealthUpdateUsageDescription] key … set these keys in the Target
  Properties list on the app's Info tab."
  Sources: <https://developer.apple.com/documentation/healthkit/running-workout-sessions>,
  <https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data>
- The **iOS companion needs neither key** in this design: the iOS app never calls
  HealthKit APIs (the design keeps `StoredMatch`/`MatchResultPayload` unchanged
  and the workout Health-app-side only). The keys are required "if your app uses
  APIs that access/update … health data" — the iOS binary won't. The app is also
  `WKRunsIndependentlyOfCompanionApp: true`, and watchOS 6+ authorization happens
  on-watch. If a later plan (e.g. 017 stats dashboard) reads workouts on iPhone,
  the iOS target gains the read key then.
- Denial/UX note for the build plan: an app cannot distinguish "denied" from "no
  data" for reads ("your app doesn't know whether someone granted or denied
  permission to read data"), and unauthorized saves fail with
  `errorAuthorizationNotDetermined`/`errorAuthorizationDenied` — this underpins
  plan 016's "denied auth ⇒ scoring unaffected" rule.
  Source: <https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data>

### 2.4 Privacy manifest (§1d) — HealthKit adds nothing

Two independent questions, both answered "no change":

1. **Required-reason API?** No. The complete category list in Apple's
   required-reason API documentation is: `NSPrivacyAccessedAPICategoryFileTimestamp`,
   `NSPrivacyAccessedAPICategorySystemBootTime`,
   `NSPrivacyAccessedAPICategoryDiskSpace`,
   `NSPrivacyAccessedAPICategoryActiveKeyboards`,
   `NSPrivacyAccessedAPICategoryUserDefaults`. HealthKit appears nowhere in the
   list (verified against the article and the `NSPrivacyAccessedAPIType` value
   enumeration on 2026-07-19). So no `NSPrivacyAccessedAPITypes` entry is added —
   unlike plan 013's File Timestamp case, where `StoreRecovery`'s
   file-creation-date reads *were* in a listed category. HealthKit's gate is the
   entitlement + user authorization sheet, not the fingerprinting-focused
   required-reason regime.
   Sources: <https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api>,
   <https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype>
2. **Collected-data disclosure (`NSPrivacyCollectedDataTypes`)?** Not for this
   design. Apple defines collect as: "'Collect' refers to transmitting data off
   the device in a way that allows you and/or your third-party partners to access
   it for a period longer than what is necessary to service the transmitted
   request in real time," and explicitly: "Data that is processed only on device
   is not 'collected' and does not need to be disclosed in your answers." The
   workout, heart-rate, and calorie samples live in the on-device HealthKit
   store; the developer never receives them (the app has no server, no
   analytics, no tracking domains — `NSPrivacyTracking` is `false` in both
   manifests). The existing WCSession transfer of match duration to the user's
   own paired iPhone gives the developer no access, so it does not meet the
   "collect" definition either. Therefore `NSPrivacyCollectedDataTypes` stays
   `[]`, and the App Store nutrition label can remain "Data Not Collected". If a
   future feature ever sends health-derived data off the user's devices to
   developer-accessible storage, the "Health" data type ("Health and medical
   data, including but not limited to data from the … HealthKit API") and/or
   "Fitness" type must then be declared in the manifest **and** in App Store
   Connect.
   Sources: <https://developer.apple.com/app-store/app-privacy-details/> (definitions of
   "collect", "Health", "Fitness", on-device exemption),
   <https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests>,
   <https://developer.apple.com/documentation/bundleresources/privacy-manifest-files>

**Correction to the ticket/plan 016 assumptions**: plan 016 says "The watch also
currently has no `PrivacyInfo.xcprivacy`". That is stale — the repo has
`BeachTennisCounter/watchOS/PrivacyInfo.xcprivacy` (byte-identical to the iOS one
except plan 013 scope: both currently declare only UserDefaults/CA92.1; plan
013's File Timestamp entry is iOS-only by design and, per its own text, "the
watch binary does not call these APIs and its manifest must stay as-is"). The
build plan should not create a watch manifest — it exists and needs no HealthKit
entry.

---

## 3. App Store review implications

Concrete obligations the HealthKit entitlement triggers (all from the App Store
Review Guidelines, <https://developer.apple.com/app-store/review/guidelines/>):

- **2.5.1 (Software Requirements)** — "Apps should use APIs and frameworks for
  their intended purposes **and indicate that integration in their app
  description**. For example … HealthKit should be used for health and fitness
  purposes and integrate with the Health app." Action item: the App Store
  description must mention the workout/Health-app integration when the feature
  ships. Recording a match as a `.tennis` workout is squarely the intended
  purpose.
- **5.1.1(i) (Privacy Policies)** — "All apps must include a link to their
  privacy policy in the App Store Connect metadata field and within the app in an
  easily accessible manner," and the policy must identify what data is collected
  and how, confirm third-party protections, and explain retention/deletion and
  consent-revocation. This applies to every app already, but a HealthKit app's
  policy must truthfully cover the health data handling (here: processed/stored
  on-device in HealthKit, never transmitted to the developer).
- **5.1.1(ii)** — "Ensure your **purpose strings** clearly and completely
  describe your use of the data." The two usage descriptions in §1b are review
  surface; vague strings ("app needs health access") are a rejection vector. The
  strings proposed in §1b state the concrete read (heart rate during match) and
  write (save match as workout).
- **5.1.2(i) (Data Use and Sharing)** — personal data may not be used, transmitted,
  or shared without permission. Moot while nothing leaves the device, but binds
  any future export/share feature (plan 018 overlap: a shared match card must not
  leak health metrics without this bar being met).
- **5.1.3 (Health and Health Research)** — the HealthKit-specific rules:
  - **5.1.3(i)**: apps "may not use or disclose to third parties data gathered in
    the health, fitness, and medical research context — including from the …
    HealthKit API … — for advertising, marketing, or other use-based data mining
    purposes other than improving health management…". Also: "You must disclose
    the specific health data that you are collecting from the device."
  - **5.1.3(ii)**: "Apps must not write false or inaccurate data into HealthKit …
    and **may not store personal health information in iCloud**." Two concrete
    consequences for the build plan: (a) the saved workout must reflect a real
    match (e.g. do not save a workout for a simulated/testing match path; end vs.
    discard on the cancel path matters — a cancelled match's partial workout
    should be discarded or honestly ended, never padded); (b) if `StoredMatch`
    ever gains workout-derived fields (calories, avg HR) **and** the SwiftData
    store ever adopts CloudKit sync, those fields would become personal health
    information in iCloud — a guideline violation. Today `StoredMatch` is
    local-only and the recommended v1 adds no health fields, so this is a
    recorded constraint, not a current problem.
  - 5.1.3(iii)/(iv) (human-subject research consent, ethics board) do not apply —
    this is not research.

None of these require new files beyond §1; they constrain App Store Connect
metadata (privacy policy URL, app description, privacy questionnaire answers) and
future data-flow decisions.

---

## 4. Summary table (what changes, per target)

| Surface | BeachTennisCounterWatch | BeachTennisCounter (iOS) |
|---|---|---|
| Entitlements | NEW block: `com.apple.developer.healthkit: true` (generated file `watchOS/BeachTennisCounterWatch.entitlements`) | unchanged |
| `.access` / `.background-delivery` entitlements | not needed | not needed |
| `WKBackgroundModes` | NEW: `[workout-processing]` in `info.properties` | n/a |
| `NSHealthShareUsageDescription` | NEW (reads heart rate) | not needed (no HealthKit calls) |
| `NSHealthUpdateUsageDescription` | NEW (saves workout) | not needed |
| pt-BR strings | append 2 keys to existing `watchOS/pt-BR.lproj/InfoPlist.strings` | unchanged |
| `PrivacyInfo.xcprivacy` | unchanged (exists; HealthKit is not a required-reason API; no data "collected") | unchanged |
| App Store Connect | privacy policy link (already mandatory), truthful privacy questionnaire ("Data Not Collected" remains valid), app description mentions Health integration | same listing |
