import Foundation

/// Build-time feature flags: things that are finished in the codebase but not
/// yet turned on for customers.
///
/// A flag here is decided when the binary is compiled, never at runtime. That
/// is a deliberate constraint, not a limitation we grew into — App Store
/// guideline 2.5.2 forbids downloading code that "introduces or changes
/// features", so a remote flag service would be the non-compliant shape and a
/// compilation condition is the compliant one. Switching a flag on therefore
/// always means editing `project.yml` and cutting a release.
///
/// This file holds the mechanism's only `#if`. Every consumer reads a plain
/// `Bool`, so both states are ordinary code that the compiler always checks
/// and tests can always reach — which matters most for the *off* state, since
/// `Release` is the one configuration nobody runs locally.
///
/// Lives in `iOS/` rather than `Shared/`: the watch target compiles `Shared/`,
/// and nothing here is the watch's business (ADR 0004 — the watch links no
/// StoreKit and shows no purchase UI). A genuinely watch-side flag, if one
/// ever appears, moves the file.
enum FeatureFlags {

    /// Whether the Pro unlock is on sale in this build.
    ///
    /// Named for the business fact rather than the code state, so it reads
    /// correctly at both of its consumers: the purchase surface exists when
    /// Pro is on sale, and `ProEntitlement.isPro` is "you own it, *or* it
    /// isn't for sale". A build where Pro is not on sale is a **dark** build:
    /// no purchase affordance anywhere, and every Pro feature free to
    /// everybody.
    ///
    /// Set by `SWIFT_ACTIVE_COMPILATION_CONDITIONS` in `project.yml` — on in
    /// `Debug` and `Dev`, absent from `Release`. That is the whole wiring;
    /// do not spell `PRO_ON_SALE` anywhere else.
    #if PRO_ON_SALE
    static let proOnSale = true
    #else
    static let proOnSale = false
    #endif
}
