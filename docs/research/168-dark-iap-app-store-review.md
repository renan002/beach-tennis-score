# Research: shipping a "dark" in-app purchase — what App Review actually requires

> Serves issue [#168](https://github.com/renan002/beach-tennis-score/issues/168)
> — shipping App Store releases with the Pro unlock built but feature-flagged off,
> then flipping the flag in a later version.

**Question**: the Pro unlock (StoreKit 2, one non-consumable `com.renan.beachtennis.pro`,
Settings purchase section, purchase sheet, Restore Purchases) is finished. We want to ship
Release builds where a compile-time flag makes every purchase affordance unreachable — the
binary still links StoreKit and still contains the code. Later we flip the flag, and
Estatísticas + Vários go behind the paywall while result cards lose their watermark.
What does App Review require at each step?

**Scope**: read-only research. Nothing below has been applied to the repo, and no
submission has been made. Repo state referenced is worktree
`wayfinder-143-145-b89108` at `6b396c5`.

**Source discipline**: primary sources only — the App Review Guidelines, App Store
Connect Help, Apple developer documentation and technotes, Apple developer news. No blog
posts, no Stack Overflow, no forum threads (forum posts are developer opinion, not Apple
policy, even on developer.apple.com). Every claim links the page that owns it. Where the
primary sources are simply silent, the finding is filed under
**[not addressed by primary sources]** with the risk read kept separate from the sourced
material — do not promote those to settled facts.

---

## 0. Bottom line

**A dark Pro build is shippable, but not by staying quiet about it.** Three things carry
the whole answer:

1. **Guideline 2.3.1(a)** forbids "hidden, dormant, or undocumented features" and requires
   that functionality be "clear to end users and App Review". Dormant is named explicitly.
   The escape hatch is disclosure, not concealment.
2. **Guideline 2.1(b)** is the exact rule for this case: *"If you offer in-app purchases in
   your app, make sure they are complete, up-to-date, visible to the reviewer and
   functional. If any configured in-app purchase items cannot be found or reviewed in your
   app, explain the reason in your review notes."* That sentence contemplates a configured
   IAP that the reviewer cannot reach, and asks for review notes rather than forbidding it.
3. **The first non-consumable IAP must be submitted with a new app version.** That is an
   App Store Connect mechanic, not a guideline — and it means the "flip the flag" release
   is *forced* to be the release that carries `com.renan.beachtennis.pro` through review.

So the two clean shapes are:

- **(A) Fully dark, IAP not submitted.** Ship Release with the flag off and leave
  `com.renan.beachtennis.pro` in *Prepare for Submission* in App Store Connect. Nothing is
  configured-and-unreachable, so 2.1(b) is not even engaged. Later, the flag-on version and
  the IAP go to review **in the same submission** — which is mandatory anyway, because it is
  our first non-consumable. This is the lowest-friction path and the recommended one.
- **(B) Dark binary, IAP submitted early.** Cannot be done for the *first* non-consumable
  without also submitting an app version, and that app version is the dark one — so the
  reviewer is handed an approved-pending product they cannot buy. Legal under 2.1(b) if the
  review notes explain it, but it buys nothing over (A) and adds a rejection surface.

What is **not** negotiable in either shape: the flag-on release must describe the new Pro
unlock specifically in Notes for Review (2.3.1(a)), must describe it in "What's New"
(2.3.12), and must indicate on the product page that features require additional purchase
(2.3.2). Paywalling Estatísticas and Vários has **no guideline forbidding it** — the
"don't take away what existing users paid for" sentence is scoped to subscriptions, and our
users paid nothing — but it is the one part of the plan with real *metadata* exposure
rather than *code* exposure.

**Restore Purchases**: keep it, and keep it reachable even in the dark build. See §3 — the
Restore obligation in 3.1.1 is written against restorable purchases existing, and a dark
build that a returning Pro customer installs is exactly the case where a reachable Restore
matters.

---

## 1. Does an unreachable-but-present IAP code path pass review?

### 1.1 The rule that names "dormant"

[Guideline 2.3.1(a)](https://developer.apple.com/app-store/review/guidelines/):

> Don't include any hidden, dormant, or undocumented features in your app; your app's
> functionality should be clear to end users and App Review. All new features,
> functionality, and product changes must be described with specificity in the Notes for
> Review section of App Store Connect (generic descriptions will be rejected) and
> accessible for review.

Two obligations, and they are different: **described with specificity**, and **accessible
for review**. A build-time flag that removes the affordance makes the Pro flow inaccessible
by construction. Read strictly, a dark build is in tension with the second clause.

2.3.1(b) sets the stakes: *"Egregious or repeated behavior is grounds for removal from the
Apple Developer Program."* The worked example Apple gives elsewhere in enforcement writing
is a hidden switch that flips an app into different content after approval — i.e. the harm
2.3.1 targets is **functionality that appears to users without passing review**. That is
the distinction the dark build must survive: our flag is a *compile-time* condition baked
into the shipped binary, so no user of that binary can reach Pro, and no server, remote
config, or downloaded code can turn it on.

### 1.2 The rule that makes it survivable

[Guideline 2.1(b), App Completeness](https://developer.apple.com/app-store/review/guidelines/):

> If you offer in-app purchases in your app, make sure they are complete, up-to-date,
> visible to the reviewer and functional. If any configured in-app purchase items cannot be
> found or reviewed in your app, explain the reason in your review notes.

This is the closest thing to an on-point rule in the entire guidelines. It presupposes the
exact situation — an IAP configured in App Store Connect that the reviewer cannot find in
the app — and prescribes review notes, not rejection. It is written from App Store
Connect's side ("configured in-app purchase items"), which is why option (A) above is
cleaner: if nothing is configured for review, the sentence has nothing to bite on.

### 1.3 Why 2.5.2 is *not* a problem, and why that matters

[Guideline 2.5.2](https://developer.apple.com/app-store/review/guidelines/):

> Apps should be self-contained in their bundles, and may not read or write data outside
> the designated container area, nor may they download, install, or execute code which
> introduces or changes features or functionality of the app, including other apps.

A `#if`-style build-time flag baked into the Release binary is the *opposite* of what 2.5.2
prohibits: the shipped binary's behaviour is fixed at compile time and can only change by
shipping a new binary through review. This is worth stating explicitly in review notes,
because it is the single strongest argument that the dark build is not the mischief 2.3.1
is aimed at. **A remote kill-switch or server-driven flag would be a different question and
a far worse one** — it would let features appear without review, which is precisely 2.3.1 +
2.5.2 territory. Keep the flag build-time.

[Guideline 2.5.1](https://developer.apple.com/app-store/review/guidelines/) adds:
*"Apps should use APIs and frameworks for their intended purposes and indicate that
integration in their app description."* Linking StoreKit while selling nothing is a soft
mismatch with that sentence, though 2.5.1's own examples are HomeKit and HealthKit
(frameworks with privacy-sensitive data), not StoreKit. Merely linking a framework has
never been the trigger.

**Verdict on Q1** — a dark IAP code path is **not per se a rejection**, and 2.1(b) is
written on the assumption that unreachable IAPs happen. But 2.3.1(a)'s "dormant" +
"accessible for review" language means the safety comes entirely from disclosure. The
minimum-risk framing in review notes: *this version does not offer any in-app purchase; the
purchase code is present but disabled at compile time in the Release configuration and
cannot be enabled without a new App Store build.*

### 1.4 [not addressed by primary sources] — the residual risk

Apple has **no published guidance, technote, or Q&A specifically about shipping disabled
in-app-purchase code**. Nothing states that dormant *code* (as distinct from dormant
*features*) is acceptable, and nothing states it isn't. The risk read: rejection here would
be discretionary and reviewer-dependent, and the most likely form is not a 2.3.1 rejection
but a **2.1 "Information Needed"** asking why the app links StoreKit / why an IAP is
configured but not offered. That is answerable with a reply, not a resubmission — which is
why the dark build is a low-cost bet, not a safe one.

---

## 2. When must the IAP record exist in App Store Connect?

### 2.1 The hard mechanic: the first non-consumable is chained to an app version

[Submit an In-App Purchase — App Store Connect Help](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/):

> Your first consumable In-App Purchase and your first non-consumable In-App Purchase must
> each be submitted with a new app version. Similarly, your first auto-renewable
> subscription and your first non-renewing subscription must each be submitted with a new
> app version.
>
> Once the first item of each type has been approved, you can submit additional items of
> that type without a new app version.

`com.renan.beachtennis.pro` is this app's **first non-consumable**. So the newer
independent-submission flow — the thing that makes people think an IAP can be reviewed on
its own — **does not apply to us yet**. Whenever we submit it, App Store Connect will
require us to attach an app version to that submission. That single fact settles most of
the sequencing question: the Pro IAP's review and the flag-on app version's review are
going to happen together whether we plan it that way or not.

### 2.2 Can it sit created-but-not-submitted?

Yes. [In-App Purchase statuses](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-statuses/):

| Status | Apple's description (verbatim, abbreviated) |
|---|---|
| **Prepare for Submission** | "Your In-App Purchase has been created, but you haven't yet submitted it for review. Use Add for Review to add it to a submission." |
| **Ready for Review** | "…added to a submission, but you haven't sent the submission to App Review yet." |
| **Waiting for Review** / **In Review** | submitted / being reviewed |
| **Approved** | "Apple has approved your In-App Purchase. For this status to appear, you must provide country or region availability…" |
| **Rejected** | "Apple has rejected your In-App Purchase during the review process." |
| **Developer Rejected** | "You removed your In-App Purchase from review." |

Nothing in that page ties a status to an app version's release state, and nothing forbids
an IAP resting indefinitely in *Prepare for Submission*. The Product ID is claimed as soon
as the record is saved, which is a reason to create it early:
[In-App Purchase information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/)
notes the Product ID is *"Not editable after you save the In-App Purchase"* and cannot be
reused even if deleted. Create `com.renan.beachtennis.pro` now, leave it unsubmitted.

**Submitted-but-not-approved while dark builds ship** is possible but pointless: since it is
the first non-consumable, submitting it drags an app version along (§2.1), and that version
would be the dark one — putting us straight into the 2.1(b) "cannot be found in your app"
conversation for no gain.

### 2.3 An approved IAP is live independently of any flag

[TN3188: Troubleshooting In-App Purchases availability in the App Store](https://developer.apple.com/documentation/technotes/tn3188-troubleshooting-in-app-purchases-availability-in-the-app-store)
lists what `Product.products(for:)` needs in production: product identifiers matching App
Store Connect, status **Approved**, country/region availability selected, and propagation
time after approval. There is **no** condition involving the app version's release state.

Consequence worth internalising: once the Pro IAP is Approved and available, it is
purchasable by *any* build that asks for it — the gate is entirely our flag, not Apple's.
[Set availability for In-App Purchases](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-availability-for-in-app-purchases/)
confirms availability edits *"go into effect immediately"*, so removing all
countries/regions is a real (if crude) kill switch, at the cost of the status flipping to
*Developer Removed from Sale*.

### 2.4 What changed with the newer flow

[Overview of submitting for review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/):

> You can choose to submit items for review together with, or separately from, an app
> version. […] If your submission doesn't include an app version, items will be reviewed
> together with the latest version of the platform you specify during the submission
> process.

and:

> A platform can have a maximum of two submissions under review at a time: one that
> includes an app version and one that includes items […] without an app version.

Apple's [October 29, 2025 developer news](https://developer.apple.com/news/?id=gf6mgrs6)
("Enhancements to help you submit and market your apps and games") widened this further:
*"Now you can send additional items to App Review independent of an existing submission."*

**But** the first-of-each-type carve-out in §2.1 is unchanged and survives all of it. The
independent flow is a *second and subsequent* IAP convenience. For issue #168 it is
background, not a mechanism we can use.

---

## 3. Must Restore Purchases be present when nothing is purchasable?

### 3.1 What the guideline actually says

[Guideline 3.1.1](https://developer.apple.com/app-store/review/guidelines/):

> Any credits or in-game currencies purchased via in-app purchase may not expire, and you
> should make sure you have a restore mechanism for any restorable in-app purchases.

The obligation is scoped to *"any restorable in-app purchases"* — i.e. it attaches to the
purchases, not to the presence of a store UI. In a dark build there are no restorable
purchases *yet*, so the letter of 3.1.1 does not compel a Restore button.

### 3.2 What the StoreKit docs say

[Restoring purchased products](https://developer.apple.com/documentation/storekit/restoring-purchased-products):

> Customers sometimes need to restore purchased content, such as when they upgrade to a new
> phone. Include some mechanism in your app, such as a Restore Purchases button, to let them
> restore their purchases.

and, importantly for our implementation:

> Don't automatically restore purchases, especially when your app launches. Restoring
> purchases prompts for the user's App Store credentials, which interrupts the flow of your
> app.

Note the second quote does **not** apply to `ProEntitlement`'s launch-time read of
`Transaction.currentEntitlements` — that is a local read that never prompts. It applies to
`AppStore.sync()`, which is the thing behind a Restore button.

### 3.3 [not addressed by primary sources] — Restore in a build that sells nothing

**Apple's documentation nowhere addresses whether a Restore affordance must exist in a
version that offers no purchases.** Every statement is written from the assumption that the
app sells something.

The risk read, kept separate from the above: **keep Restore reachable even in the dark
build.** Two reasons, one forward-looking and one about the review itself.

- Forward-looking: the moment a *later* version sells Pro, every earlier dark build is
  still installed on devices. A customer who buys Pro on v1.4, then reinstalls or moves to a
  new phone and lands on an older binary, has a restorable purchase and no way to invoke it.
  That is the scenario 3.1.1 and the StoreKit doc are both about.
- Review: a reachable Restore button is a *disclosed* purchase-adjacent affordance. It makes
  the app's monetisation posture visible to the reviewer rather than dormant, which is
  directly aligned with 2.3.1(a)'s "clear to end users and App Review".

The counter-consideration: a Restore button in an app that sells nothing may itself prompt a
2.1 "Information Needed" ("what is there to restore?"). That is again a review-notes answer,
not a resubmission. On balance, ship Restore; explain it in the notes.

---

## 4. Revealing a previously dark IAP in a later version

### 4.1 The IAP gets its own review, and it is mandatory

Per §2.1, the first non-consumable must ride an app version — so the reveal release **is**
the review. Both the app version and `com.renan.beachtennis.pro` are in one submission and
are reviewed together
([Overview of submitting for review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/):
*"If your submission includes an app version […] items will be reviewed together with that
app version."*).

If any item in a joint submission is rejected, the accepted ones stall — the **Accepted**
status means *"Your In-App Purchase has been accepted, but one or more other items in the
same submission were rejected. Your In-App Purchase won't be approved until all items in the
submission are accepted."*
([statuses](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-statuses/)).
So a metadata nit on the IAP blocks the app version and vice versa.

### 4.2 Required IAP metadata

From [In-App Purchase information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/):

- **Reference Name** — internal only, ≤64 chars, editable any time without review.
- **Product ID** — ≤100 chars, **not editable after saving**, never reusable.
- **Availability** — countries/regions. Required for the *Approved* status to appear at all.
- **Pricing**.
- **Localizable Information**, at least one language: **Display Name** 2–30 chars,
  **Description** max 45 chars. Both are customer-facing.
- **Review Information**: **App Review Screenshot** (required) and **Review Notes**
  (≤4000 chars).

On the screenshot, verbatim:

> A screenshot of the In-App Purchase that clearly shows the item or service being offered.
> This screenshot is used for review only and isn't displayed on the App Store.

Two repo-specific consequences. First, the Display Name and Description are **customer-facing
strings that App Store Connect owns, not `Shared/Localizable.xcstrings`** — pt-BR copy for
Pro has to be authored in App Store Connect separately, and the 30/45-character limits are
tight for Portuguese. Second, the App Review Screenshot has to *show the offer*, which means
it must be captured from a **flag-on build** — a screenshot of the dark build cannot satisfy
"clearly shows the item or service being offered".

### 4.3 Product page and release notes

- [Guideline 2.3.2](https://developer.apple.com/app-store/review/guidelines/): *"If your app
  includes in-app purchases, make sure your app description, screenshots, and previews
  clearly indicate whether any featured items, levels, subscriptions, etc. require additional
  purchases."* The reveal release must update the App Store description and any screenshot
  that shows Estatísticas or Vários, because those now require purchase. This is the concrete
  metadata work item and it is easy to forget.
- [Guideline 2.3.12](https://developer.apple.com/app-store/review/guidelines/): *"Apps must
  clearly describe new features and product changes in their 'What's New' text. Simple bug
  fixes, security updates, and performance improvements may rely on a generic description, but
  more significant changes must be listed in the notes."* Introducing a paid tier and moving
  two features behind it is unambiguously a "significant change".
- [Guideline 2.3.1(a)](https://developer.apple.com/app-store/review/guidelines/): Notes for
  Review must describe the change **with specificity** — *"generic descriptions will be
  rejected"*.

### 4.4 Price and availability scheduling

Availability changes *"go into effect immediately"*
([Set availability](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-availability-for-in-app-purchases/)),
and TN3188 warns that after approval *"it may take some time for them to become available in
all selected countries or regions."*

**[not addressed by primary sources]** — Apple documents no way to *schedule* an IAP to
become available at the same instant an app version goes live. Risk read: expect a window
around release where the app version is live and the product is still propagating, and make
sure the purchase sheet degrades gracefully when `Product.products(for:)` returns empty.
`ProEntitlement` should already handle that path — it is the same empty-product state the
simulator shows for a `simctl`-installed build (per `CLAUDE.md`), so the behaviour is
already observable locally.

---

## 5. Does paywalling previously-free Estatísticas and Vários have a review dimension?

### 5.1 There is no guideline prohibiting it

Searching the guidelines for a rule against moving free functionality behind an IAP turns up
exactly one adjacent sentence, and it does not apply. [Guideline 3.1.2(a)](https://developer.apple.com/app-store/review/guidelines/):

> If you are changing your existing app to a subscription-based business model, you should
> not take away the primary functionality existing users have already paid for. For example,
> let customers who have already purchased a "full game unlock" continue to access the full
> game after you introduce a subscription model for new customers.

Three reasons this is not our case: it lives under **3.1.2 Subscriptions** and we are
shipping a **non-consumable**; it says *"changing your existing app to a subscription-based
business model"*, which we are not; and its object is *"functionality existing users have
already paid for"*, whereas Beach Tennis Score is free and no user has paid for anything.

[Guideline 3.1.1](https://developer.apple.com/app-store/review/guidelines/) is affirmatively
on our side: *"If you want to unlock features or functionality within your app, (by way of
example: subscriptions, in-game currencies, game levels, access to premium content, or
unlocking a full version), you must use in-app purchase."* Gating Estatísticas and Vários
behind a StoreKit non-consumable is the sanctioned mechanism.

The other candidates all miss. [3.2.2(v)](https://developer.apple.com/app-store/review/guidelines/)
covers *"Arbitrarily restricting who may use the app, such as by location or carrier"* —
about geography and carriers, not payment. [3.2.2(x)](https://developer.apple.com/app-store/review/guidelines/)
forbids forcing users to *"rate the app, review the app, download other apps, or other
store-related actions in order to access functionality"* — and explicitly permits
incentivising in-app actions; a paid unlock is not a store-related action in that sense.

### 5.2 The real exposure is metadata and scam-adjacency

The bait-and-switch language in [3.1.2(a)](https://developer.apple.com/app-store/review/guidelines/):

> Apps that attempt to scam users will be removed from the App Store. This includes apps
> that attempt to trick users into purchasing a subscription under false pretenses or engage
> in bait-and-switch and scam practices; these will be removed from the App Store and you may
> be removed from the Apple Developer Program.

Again subscription-framed, but "bait-and-switch" is the phrase a reviewer would reach for if
the product page still advertised Estatísticas as a free feature *after* it went paid. That
makes the 2.3.2 product-page update (§4.3) the mitigation for this risk too, not just a
housekeeping item. The compliance work for Q5 is entirely in App Store Connect metadata —
description, screenshots, What's New — and none of it is in the code.

### 5.3 [not addressed by primary sources] — the watermark change

Removing the result-card watermark for Pro users is a **cosmetic differentiator on a
non-consumable**, and Apple's documentation says nothing about it either way. Risk read:
this is the least exposed part of the whole plan. The one thing to preserve is the existing
`CLAUDE.md` rule that the Cartão de Resultado is a publicly-posted image and must never carry
the `DEV` marker; a Pro watermark is a different string with a different rule, and the two
should not be conflated in the code that composes the card.

---

## 6. Demo account / reviewer access

This is where the dark build's obligations are most concrete, and Apple states them in three
places.

[Guideline 2.1(a)](https://developer.apple.com/app-store/review/guidelines/):

> …include demo account info (and turn on your back-end service!) if your app includes a
> login. If you are unable to provide a demo account due to legal or security obligations,
> you may include a built-in demo mode in lieu of a demo account with prior approval by
> Apple. Ensure the demo mode exhibits your app's full features and functionality.

The [Before You Submit](https://developer.apple.com/app-store/review/guidelines/) checklist:

> Provide App Review with full access to your app. If your app includes account-based
> features, provide either an active demo account or fully-featured demo mode, plus any other
> hardware or resources that might be needed to review your app (e.g. login credentials or a
> sample QR code)

> Include detailed explanations of non-obvious features and in-app purchases in the App
> Review notes, including supporting documentation where appropriate

And [Guideline 2.1(b)](https://developer.apple.com/app-store/review/guidelines/), quoted in
full in §1.2.

**Reading for this app.** Beach Tennis Score has **no login and no back end**, so the
demo-account requirement in 2.1(a) does not attach — there is no account to demo. What does
attach is the "full access" / "non-obvious features" language: the reviewer must not be left
to discover the StoreKit linkage on their own.

Note also that the demo-mode escape hatch in 2.1(a) is **not** a template for a hidden
reviewer-only unlock. It is scoped to *login* substitutes, requires *"prior approval by
Apple"*, and a build-flag-plus-secret-gesture that reveals Pro to reviewers only would be
the paradigm 2.3.1 "hidden feature". **Do not build a reviewer backdoor.** The dark build
should be dark for everyone including the reviewer, and the review notes carry the
explanation.

There is a **watchOS-specific** fact worth recording from
[Submit an In-App Purchase](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/):

> In-App Purchases and subscriptions are not supported on Apple Watch.

That is consistent with ADR 0004 and the existing `ProEntitlementTests` rule that
`ProEntitlement` stays in `iOS/` — but it is now an Apple-sourced reason, not only an
architectural preference, and it should be said in review notes if a reviewer wonders why the
watch app never mentions Pro.

### 6.1 Draft review notes for the dark release

Not a source claim — a proposed artefact, to be adapted:

> This version does not offer any in-app purchase. The app is free and all features are
> available to every user. The binary links StoreKit and contains an unfinished Pro-unlock
> code path, which is disabled by a compile-time flag that is off in the Release build
> configuration; it cannot be enabled remotely or by any user action, only by shipping a new
> build through App Review. A "Restore Purchases" control is present in Settings so that
> customers of a future paid version can restore on this build. No in-app purchase products
> are submitted or available for this version. In-app purchases are not supported on Apple
> Watch, so the watchOS app contains no purchase code.

### 6.2 One local hygiene note

`CLAUDE.md` records that `Pro.storekit` is wired into the run action of the
`BeachTennisCounter` and `Beach Dev` schemes. Per
[Setting up StoreKit Testing in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode),
a StoreKit configuration is a *scheme run-action* setting: it affects only runs launched from
Xcode and is not part of the built product, so it does not travel into an archive or an App
Store build. No action needed — recorded here so nobody removes it out of submission anxiety.

---

## 7. Source inventory

Every page consulted, so the next reader can re-verify rather than trust this file:

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — 2.1(a), 2.1(b), 2.3.1, 2.3.2, 2.3.12, 2.5.1, 2.5.2, 3.1.1, 3.1.2(a), 3.2.2(v), 3.2.2(x), Before You Submit
- [Submit an In-App Purchase](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/) — first-of-type rule, watchOS exclusion
- [Overview of submitting for review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/) — joint vs independent submissions, two-at-a-time limit
- [In-App Purchase statuses](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-statuses/) — full status table
- [In-App Purchase information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/) — required fields, review screenshot
- [Set availability for In-App Purchases](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-availability-for-in-app-purchases/)
- [TN3188: Troubleshooting In-App Purchases availability in the App Store](https://developer.apple.com/documentation/technotes/tn3188-troubleshooting-in-app-purchases-availability-in-the-app-store)
- [Restoring purchased products](https://developer.apple.com/documentation/storekit/restoring-purchased-products)
- [Setting up StoreKit Testing in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)
- [Apple developer news, October 29, 2025 — "Enhancements to help you submit and market your apps and games"](https://developer.apple.com/news/?id=gf6mgrs6)

Developer Forums threads were deliberately excluded: they are developer opinion hosted on
Apple's domain, not Apple policy, and several of the loudest claims about restore-button
requirements and dark IAPs trace back to forum posts rather than to any Apple text.
