# Research: how sports apps build shareable result cards, and what the Cartão de Resultado should borrow

**Question**: What do Strava and comparable sports/fitness apps put on a shared
activity card, how much control do they give the user, and which of those
features are worth adopting for our **Cartão de Resultado** (issues
[#74](https://github.com/renan002/beach-tennis-score/issues/74) /
[#75](https://github.com/renan002/beach-tennis-score/issues/75))?

**Scope**: read-only prior-art research. Nothing below has been applied. Repo
state referenced is worktree `kind-hugging-rabbit` on branch
`proto/75-result-card-variants`; current implementation is
`BeachTennisCounter/iOS/Models/ResultCard.swift`,
`BeachTennisCounter/iOS/Views/ResultCardView.swift`, and the four variants in
`BeachTennisCounter/iOS/Views/ResultCardVariantsPrototype.swift`.

**Our constraints** (from #74/#75 and `CONTEXT.md`): release 1.4 is free,
watermarked, **no StoreKit**, fully offline, iPhone-only; the watch never shows
purchase UI. Pro (watermark removal) arrives in release 2.

**Source discipline**: every claim links to the vendor's own help centre,
developer docs or legal pages. Two sources are flagged **[secondary]** where no
primary page carried the detail.

---

## 1. Feature inventory: what the field actually ships

### 1.1 Strava

| Feature | What Strava does | Source |
|---|---|---|
| Share target | Share icon on the feed row or the activity detail opens a "Share To" list of apps — Instagram, WhatsApp, Messages, email; the website only posts to X. | [Sharing Your Strava Activities](https://support.strava.com/en-us/articles/15401840-sharing-your-strava-activities), [Social Sharing of your Strava Activities](https://support.strava.com/hc/en-us/articles/221089587-Social-Sharing-of-your-Strava-Activities) |
| Card background | Either the **route map** or **one of your attached photos** — if photos exist you are prompted to choose, otherwise the map is used. | [Sharing Your Strava Activities](https://support.strava.com/en-us/articles/15401840-sharing-your-strava-activities) |
| Stats on the card | A **fixed** set, not user-chosen: "moving time, distance, and elevation for rides, and moving time, distance, and pace for runs and swims". | [Sharing Your Strava Activities](https://support.strava.com/en-us/articles/15401840-sharing-your-strava-activities) |
| Per-stat toggles | **None** in the first-party share image ("we only share…"). | same |
| Precondition | Only GPS-recorded activities can be shared with a map or stats image; stationary/indoor/manual activities cannot. | same |
| Photo attachment | Photos and videos are attached to the activity first, then become share backgrounds. | [Adding Videos and Photos to Your Activity](https://support.strava.com/en-us/articles/15401859-adding-videos-and-photos-to-your-activity) |
| Animated / video export | **Flyover** — an animated 3D fly-through of the route with live overlay stats (speed, distance, elevation), shareable to Instagram Stories. **Subscriber-only**, generated server-side with a push notification when long activities finish. | [Flyover](https://support.strava.com/en-us/articles/15401641-flyover) |
| Off-platform composer | **Snapchat lens**: overlays distance, elevation, moving time, sport type and a map polyline on *your own* photos and videos; lists your 30 most recent activities; respects "Only You" privacy and hidden map portions. | [SnapChat and Strava](https://support.strava.com/en-us/articles/15401686-snapchat-and-strava) |
| Live-capture overlay | Oakley / Ray-Ban Meta glasses can burn chosen metrics (distance, pace, HR, power) onto captured photo/video. | [Connecting Meta Glasses with Strava](https://support.strava.com/hc/en-us/articles/40392162161293-Connecting-Meta-Glasses-with-Strava) |
| Instagram Stories stickers | "Stats Stickers" let you put activity stats on *any* image inside IG Stories rather than being limited to one summary image. **[secondary — Strava Community Hub post, returned 403 to direct fetch; summarised from the indexed search result]** | [Community Hub: Use Strava Stats Stickers on IG Stories](https://communityhub.strava.com/what-s-new-10/use-strava-stats-stickers-on-ig-stories-ios-android-9344) |
| Deep link back | Separate "get a link" flow and an **embed** widget for activities/routes — sharing a *link* is a distinct affordance from sharing an *image*. | [How to Get and Share Links From Strava](https://support.strava.com/hc/en-us/articles/4418607378189-How-to-Get-and-Share-Links-From-Strava), [Sharing Your Activities and Routes With a Strava Embed](https://support.strava.com/en-us/articles/15402053-sharing-your-activities-and-routes-with-a-strava-embed) |

**The shape of Strava's product decision**: one opinionated template, a fixed
stat set, background choice as the only real user control, and the ambitious
stuff (Flyover) behind the subscription. Customisation is pushed *out* to the
destination platform (Snapchat lens, IG stickers) rather than built as an
in-app composer.

### 1.2 Nike Run Club

Share flow lives on the Activity tab: pick a run, tap **Share your run**, then
"customise a photo or poster with stickers and run data" before choosing the
social channel — i.e. a **poster template** path *and* a **photo background**
path, with sticker decoration on top.
([Nike Help: How Do I Share My NRC Run on Social Media?](https://www.nike.com/help/a/nrc-share) —
the page 403s to automated fetch; wording above is from Nike's own indexed help
text, **[secondary in retrieval, primary in authorship]**.)

### 1.3 Garmin Connect

Open activity → share → **"Photo with Stats"** → pick a camera-roll photo or
take one → **Data** toggle adds activity stats → **Stickers** adds decorative
stickers, which are **draggable** to position them.
([Garmin: Sharing Your Garmin Connect Activity With Photos and Stickers](https://support.garmin.com/en-US/?faq=DVP5X0X0tV0kgEYzqK9zB7),
[Garmin Blog: Customize Your Garmin Connect Photos with New Stickers](https://www.garmin.com/en-US/blog/fitness/customize-garmin-connect-photos-with-stickers/))

Notably, **which** stats appear is not user-selectable; a long-running Garmin
forum request asks exactly for that and it remains unshipped
([forum thread — **[secondary, user content]**](https://forums.garmin.com/developer/connect-iq/f/app-ideas/229488/customize-stats-shown-when-activity-shared)).
So the two largest fitness platforms both ship a *fixed* stat set.

### 1.4 WHOOP

**WHOOP Live** overlays real-time WHOOP data (HR, Day Strain, Recovery, Sleep)
onto a video or an image; you pick a **mode** that determines the metric set,
**pinch to resize and drag to reposition** the overlays, and **swipe to cycle
filters**; you can also upload an existing photo from the library, then save or
send to a platform.
([WHOOP Support: WHOOP Live](https://support.whoop.com/hc/en-us/articles/360023429833-WHOOP-Live) —
403 to automated fetch, summarised from WHOOP's own indexed support text,
**[secondary in retrieval]**.)

This is the fullest **in-app composer** of the group: freeform overlay
placement plus photo filters.

### 1.5 Runna

Runna generates **plan progress graphs** and **highlight images** and pushes
them automatically to Strava as activity media, with a "Sync Plan Progress"
toggle to switch it off. Since June 2025 it also appends **"with Runna ✅"** to
the synced workout title/description.
([Runna Support: Managing Automatic Media Uploads from Runna to Strava](https://support.runna.com/en/articles/11775028-managing-automatic-media-uploads-from-runna-to-strava))

That title suffix is a pure growth loop: Runna's brand rides into someone
else's social feed on every synced run, with a user opt-out.

### 1.6 SwingVision (the racket-sport comparable)

SwingVision's share unit is **video, not a still card**: open session details →
**Share Video** → **Share Link**, and the recipient watches on the web with no
account.
([SwingVision: Track Your Match](https://swing.vision/guides/track-your-match),
[Review Your Match Footage](https://swing.vision/guides/review-your-video-footage))
Its Pro tier adds **AI Scoring with "TV-quality scoreboards & match stats"**
burned into the video
([SwingVision Pro plans](https://swing.vision/subscribe)), and the AI edit
compresses a 2-hour match into ~15 minutes of highlights
([SwingVision home](https://swing.vision/home/)).

Relevance to us: the racket-sport prior art is **link-to-hosted-video**, which
needs accounts, a backend and network — the exact opposite of our constraints.
It confirms that a *still* score card is an unoccupied niche in this segment,
not that we should chase video.

### 1.7 Apple Fitness

Apple's own "share your activity" is **friend-to-friend ring sharing inside the
Fitness app**, not an exportable social image
([Share your activity in Fitness on iPhone](https://support.apple.com/guide/iphone/share-your-activity-iph0b826155d/ios),
[Share your activity from Apple Watch](https://support.apple.com/guide/watch/share-your-activity-apd68a69f5c7/watchos)).
Apple therefore offers **no template to copy** here — only the platform APIs in
§2.

---

## 2. Feasibility for us, with the iOS API for each

Our current stack: a pure `ResultCard` model → `ResultCardView` → `ImageRenderer`
→ `ShareableResultCard: Transferable` → `ShareLink`. Everything below is judged
against offline / no-accounts / no-network / iPhone-only.

| Feature seen in the field | Feasible? | iOS API + Apple citation |
|---|---|---|
| **Still card rendered on-device from SwiftUI** (what we do today) | ✅ Already shipped | [`ImageRenderer`](https://developer.apple.com/documentation/swiftui/imagerenderer) — `scale`, `isOpaque`, `uiImage`/`cgImage`, `render(rasterizationScale:)`; must run on the main actor. |
| **Standard share sheet** (Strava, NRC, Garmin all use the OS sheet) | ✅ Already shipped | [`ShareLink`](https://developer.apple.com/documentation/swiftui/sharelink) (iOS 16+), item must be [`Transferable`](https://developer.apple.com/documentation/coretransferable/transferable); we use `DataRepresentation(exportedContentType: .png)`. |
| **Share-sheet preview thumbnail** (so the card is visible before choosing the app) | ✅ Cheap win | `ShareLink(item:preview:)` with `SharePreview(title, image:)` — same [ShareLink](https://developer.apple.com/documentation/swiftui/sharelink) doc. Renders once at low scale; no new dependency. |
| **Multiple templates / themes** (NRC "poster", our four variants) | ✅ Cheap, pure SwiftUI | Nothing beyond `ImageRenderer`; a template enum drives which `View` is fed to it. Model stays untouched — this is exactly the seam #74 specified. |
| **Two aspect ratios: 1:1 square + 9:16 story** | ✅ Cheap | Parameterise `ResultCardView.side` into a `size: CGSize`; render twice, or offer a picker. `ImageRenderer` takes whatever the view's `.frame` proposes ([ImageRenderer](https://developer.apple.com/documentation/swiftui/imagerenderer)). Note Strava users complain about being handed a fixed ratio ([Community Hub — **[secondary, user content]**](https://communityhub.strava.com/strava-features-chat-5/shared-saved-photos-exported-in-16-9-aspect-ratio-9230)). |
| **Photo background from the camera roll** (Strava/Garmin/NRC/WHOOP all have it) | ✅ Feasible, **no permission prompt** | [`PhotosPicker`](https://developer.apple.com/documentation/photokit/photospicker) (SwiftUI, iOS 16+) over [`PHPickerViewController`](https://developer.apple.com/documentation/photokit/phpickerviewcontroller): system-rendered, out-of-process, so the app gets the chosen asset **without requesting photo-library authorization**. Fully offline. The item is `Transferable`; load with `loadTransferable(type:)`. |
| **Save card to Photos** (rather than share) | ⚠️ Feasible but adds a permission prompt | Writing to the library needs [`NSPhotoLibraryAddUsageDescription`](https://developer.apple.com/documentation/bundleresources/information-property-list/nsphotolibraryaddusagedescription) — "required if your app uses APIs that have write access to the user's photo library". The share sheet already offers "Save Image" with no prompt, so this is redundant cost. |
| **Freeform draggable overlays / stickers** (WHOOP, Garmin) | ⚠️ Technically possible, poor fit | Pure SwiftUI gestures + `ImageRenderer`; but see §3 — a 2-number scoreboard has nothing to arrange. |
| **Per-stat toggles** | ⚠️ Possible, but neither Strava nor Garmin ships it | Trivial booleans into the model. See §3 for why it's the wrong call. |
| **Animated / video export** (Strava Flyover, SwingVision) | ❌ Out of scope for 1.4 | Would mean rendering frames with `ImageRenderer` into `CVPixelBuffer`s and writing them with [`AVAssetWriter`](https://developer.apple.com/documentation/avfoundation/avassetwriter) (modern `inputPixelBufferReceiver(for:pixelBufferAttributes:)`; `AVAssetWriterInputPixelBufferAdaptor` is deprecated). Large, and Strava gates its equivalent behind a subscription anyway. |
| **Map / route imagery** | ❌ Not applicable | We record no GPS. This is the single biggest reason the running-app template does not transfer: Strava's card is *a picture of where you went*; ours is *a picture of who won*. |
| **Deep link / hosted page back to the app** (Strava links & embeds, SwingVision share links) | ❌ Needs a backend and accounts | Rejected by #74 ("no backend, accounts, receipt validation server, or analytics"). An App Store URL in the share text is the offline-safe substitute (see §5). |
| **Off-platform composers** (Snapchat lens, IG Stats Stickers) | ❌ Network + partner integration | Requires network and a partner relationship. Non-starter for 1.4. |

**A Swift 6 note for anything added here**: the card model is `Sendable` and the
render path is `@MainActor` (`ResultCardView.rendered(scale:)`,
`ShareableResultCard.pngData()`), matching the repo's existing rule that
`Sendable` values are extracted before crossing actor boundaries. A photo
background would add a `UIImage`/`Data` payload that must be resolved *before*
the `@MainActor` render, not inside the `Transferable` closure's async context.

---

## 3. Prioritised shortlist for a beach-tennis score card

**Do these (in order):**

1. **Pick one strong template and ship it.** Strava, NRC and Garmin all lead
   with a single opinionated layout; none of them lets you rearrange the
   scoreboard. Our four prototype variants should converge to **one default**,
   not four options in the UI. (Prior art: Strava's fixed stat set,
   [Sharing Your Strava Activities](https://support.strava.com/en-us/articles/15401840-sharing-your-strava-activities).)
2. **Add a `SharePreview` to the `ShareLink`.** One line; the user sees the card
   thumbnail in the sheet before choosing WhatsApp vs Instagram. Pure API win
   ([ShareLink](https://developer.apple.com/documentation/swiftui/sharelink)).
3. **Offer 1:1 and 9:16.** Our card is square today, which is right for WhatsApp
   and the IG grid but letterboxes in Stories — where the beach-tennis audience
   actually posts. Strava users complain about exactly this fixed-ratio problem
   ([**[secondary]**](https://communityhub.strava.com/strava-features-chat-5/shared-saved-photos-exported-in-16-9-aspect-ratio-9230)).
   Cheapest high-value differentiator we have.
4. **Photo background (post-match court/team photo) as the one user control.**
   This is the *only* customisation all four majors converge on, and
   `PhotosPicker` gives it to us **offline with no permission prompt**
   ([PHPickerViewController](https://developer.apple.com/documentation/photokit/phpickerviewcontroller)).
   It also replaces the map: our card gets a background that carries the story,
   which is what Strava's route image does for runners. Scoreboard stays fixed
   on top; a scrim keeps the text legible.
5. **A theme/colour treatment tied to the existing team colours.** We already
   pass `teamAColor`/`teamBColor` into the view; leaning on them costs nothing
   and makes the card feel like *this* pair's card.

**Deliberately not doing:**

- **Per-stat toggles.** Neither Strava nor Garmin ships them despite years of
  requests ([Garmin forum, **[secondary]**](https://forums.garmin.com/developer/connect-iq/f/app-ideas/229488/customize-stats-shown-when-activity-shared)).
  Our card has five facts total (teams, score, winner, date, duration) — a
  toggle UI would be larger than the thing it configures.
- **Draggable stickers / freeform composer** (WHOOP, Garmin). Those exist to
  decorate *a photo*; our subject is a scoreboard whose whole job is to be
  instantly legible. Freeform placement can only make it worse.
- **Video / animated export.** Strava's Flyover is server-generated and
  subscriber-gated; SwingVision's is the entire product. `AVAssetWriter` work
  for a static score is disproportionate.
- **Map/route imagery.** No GPS in our data model; nothing to draw.
- **Hosted share links / embeds.** Backend and accounts, both excluded by #74.
- **Multiple selectable templates in the shipping UI.** Keep the variants as a
  design-time prototype (`ResultCardVariantsPrototype.swift`), not a runtime
  picker — a picker adds a decision before every share.

---

## 4. Watermark and branding as a growth loop

**The practice is standard and vendors treat it as an asset, not a defect.**

- **Strava requires attribution of *others* on shared media.** Its brand
  guidelines state that apps displaying the "Powered by Strava" / "Compatible
  with Strava" logos must do so on "all websites, apps and any distributable
  media such as images, videos or prints", with **no variations or
  modifications** permitted, and that Strava branding must stay "completely
  separate and apart from" the app's own identity and must not appear more
  prominently than it
  ([Strava brand guidelines](https://developers.strava.com/guidelines/)).
  The [API Policy](https://www.strava.com/legal/api_policy) adds that you must
  not use a Strava mark as the name, icon or branding of your app.
  → **Direct read-across for us**: our watermark is *our own* name on *our own*
  render of *our own* data, so none of this binds us. It only binds us if we
  ever ingest third-party data.
- **Runna brands the artefact itself**, appending "with Runna ✅" to synced
  activity titles, with a user-facing toggle to turn media sync off
  ([Runna Support](https://support.runna.com/en/articles/11775028-managing-automatic-media-uploads-from-runna-to-strava)).
  Evidence that "brand rides along on shared output, with an escape hatch" is a
  shipped, tolerated pattern — and our escape hatch is Pro.
- **SwingVision gates the polished, brand-bearing artefact** (TV-quality
  scoreboards) behind Pro ([SwingVision Pro](https://swing.vision/subscribe)),
  the mirror image of our plan: we give the artefact away and charge to remove
  the brand.

**Platform rules that could constrain us — checked, and they don't.**

- The [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
  contain **no rule against placing your own branding or watermark on content
  your app generates and the user exports**. The advertising rule, **2.5.18**,
  governs *display advertising* ("Display advertising should be limited to your
  main app binary… Interstitial ads or ads that interrupt or block the user
  experience must clearly indicate that they are an ad…") — a static app name
  on an image the user chose to create and share is not display advertising,
  and it is not an interstitial.
- **4.1(c)**: "You cannot use another developer's icon, brand, or product name
  in your app's icon or name, without approval from the developer." Ours is our
  own name — fine. Keep it that way: don't put Instagram/WhatsApp marks on the
  card.
- **2.3.10**: don't include "names, icons, or imagery of other mobile platforms
  or alternative app marketplaces" in the app or its metadata. Relevant only if
  we were tempted to draw platform logos on the card. Don't.
- **5.2.5(a)**: don't imply Apple is a source or supplier, or endorses the app.
  Keep Apple marks off the card.
- **3.1.1** is the one that bites in **release 2**, not 1.4: "If you want to
  unlock features or functionality within your app… you must use in-app
  purchase. Apps may not use their own mechanisms to unlock content or
  functionality, such as license keys…". So watermark removal **must** be a
  StoreKit non-consumable — which is already what #74/ADR 0004 specify. It also
  means 1.4 shipping with no StoreKit at all is clean: there is nothing to
  unlock yet.
- **Sharing itself is unconstrained** as long as we don't harvest Contacts or
  Photos to message people — **5.1.2(v)** limits contacting people using
  collected Contacts/Photos data. Our flow is the user's own share sheet
  invocation, so it is squarely inside "at the explicit initiative of that
  user".

**Practical implications for the watermark's design.** Our
`ResultCard.appWatermark` is `"Beach Tennis Score"`, unlocalized, and #75 asks
for "small but legible". The prior art suggests two refinements worth
considering: (a) keep it in a **consistent corner across every template and
aspect ratio**, the way Strava insists third parties do with its own marks
([brand guidelines](https://developers.strava.com/guidelines/)) — recognisability
comes from repetition, not size; and (b) if a photo background lands, the
watermark needs a **scrim or shadow**, because it is the one element that must
survive an arbitrary background. In release 2, #74's "tap the watermark to buy
Pro" touchpoint is only reachable in the in-app card preview, never in the
exported PNG — worth stating explicitly so nobody tries to encode a link into
the image.

**One growth-loop gap worth flagging.** Every app above has a path back:
Strava has links and embeds, SwingVision has a public watch page, Runna has the
title suffix inside Strava's feed. Our exported PNG is a dead end — a viewer
who likes the card has only the app's name to type into App Store search, which
#74 already names as our sole acquisition channel. Offline-safe options, in
increasing order of intrusiveness: put the App Store short URL in the
`ShareLink`'s `message:`/`subject:` text alongside the image
([ShareLink](https://developer.apple.com/documentation/swiftui/sharelink)
supports both), or render a small App Store URL under the watermark. Neither
needs network, a backend, or a permission. This is the highest-leverage
watermark decision available and is worth settling in 1.4, while the watermark
design is still open.

---

## 5. Summary of what changes for us

Nothing in the field's feature set argues we are missing something structural —
our model → view → `ImageRenderer` → `Transferable` → `ShareLink` pipeline is
exactly how a first-party still card is built, and it already does offline what
Strava does with a server. The gaps are four small, cheap ones: a
`SharePreview`, a 9:16 story size, an optional `PhotosPicker` background, and a
decision about whether the watermark carries a findable App Store URL. The
expensive features the majors ship — maps, video, freeform composers, hosted
links — are either impossible without a backend or meaningless for a two-number
scoreboard.
