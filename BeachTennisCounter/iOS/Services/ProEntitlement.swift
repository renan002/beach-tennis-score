import Foundation
import StoreKit

/// The Pro unlock: one non-consumable lifetime purchase, iPhone-only.
///
/// StoreKit is the sole source of truth — there is no flag of our own in
/// `UserDefaults`, no receipt server, nothing to keep in sync. `isPro` is
/// recomputed from `Transaction.currentEntitlements` at launch and again
/// whenever StoreKit reports a transaction, which is what makes a purchase
/// (or a restore, or an Ask-to-Buy approval, or a refund) land live with no
/// restart.
///
/// Lives in `iOS/`, never `Shared/`: the watch target links no StoreKit and
/// renders no purchase UI (ADR 0004). Injected like the session managers.
@MainActor
final class ProEntitlement: ObservableObject {
    /// The App Store Connect product id. Deliberately unflavored — a dev-flavor
    /// build has its own bundle id and therefore no App Store record at all, so
    /// it demos against the local `Pro.storekit` configuration, which declares
    /// this same id (pinned by `ProEntitlementTests`).
    nonisolated static let productID = "com.renan.beachtennis.pro"

    static let shared = ProEntitlement()

    /// The only thing any gate should ever read.
    @Published private(set) var isPro = false

    /// The store's product, once loaded — `nil` while loading, and on a device
    /// that cannot reach the store. The purchase sheet shows its localized
    /// `displayPrice` rather than a price we hardcode.
    @Published private(set) var product: Product?

    /// Drives the sheet's button states. Separate flags, because Restore is
    /// reachable from Settings without the sheet.
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false

    private var updatesTask: Task<Void, Never>?

    /// Outcome of a purchase attempt, returned to whoever presented the sheet.
    /// `pending` is Ask to Buy: nothing is owed yet, and the entitlement will
    /// arrive later through the transaction listener.
    ///
    /// Outcomes are *returned*, never published: two surfaces can offer Restore,
    /// and a failure one of them provoked must not surface as an alert on the
    /// other later on.
    enum PurchaseOutcome: Equatable {
        case purchased
        case pending
        case cancelled
        /// Carries what to show the user — StoreKit's own message where it has
        /// one, ours where the store simply has no product.
        case failed(String)
        /// A second tap while the first attempt is still running.
        case busy
    }

    /// Outcome of a Restore Purchases tap. "Nothing to restore" and "it failed"
    /// are deliberately different answers: telling a buyer whose sync failed
    /// that they own nothing is the one wrong thing this button can say.
    enum RestoreOutcome: Equatable {
        case restored
        case nothingToRestore
        case cancelled
        case failed(String)
        case busy
    }

    /// Shown when the store has no product to sell or hands back something
    /// unverifiable — both are "not now", not "you did something wrong".
    private static var unavailableMessage: String {
        String(localized: "Pro is unavailable right now. Please try again later.")
    }

    private init() {}

    /// Starts the transaction listener and takes the first entitlement reading.
    /// Called once, at app launch, before any UI can ask about `isPro`.
    ///
    /// The listener is started *before* the first reading so a transaction that
    /// arrives during launch cannot slip between the two.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refresh() }
        Task { await loadProduct() }
    }

    /// Recomputes `isPro` from what StoreKit currently grants this Apple
    /// Account. Unverified entitlements are ignored: a transaction that fails
    /// Apple's signature check is not an unlock.
    func refresh() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.productID else { continue }
            guard transaction.revocationDate == nil else { continue }
            entitled = true
        }
        isPro = entitled
    }

    @discardableResult
    func loadProduct() async -> Product? {
        if let product { return product }
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            product = nil
        }
        return product
    }

    /// Runs the standard App Store purchase flow. Safe to call with no product
    /// loaded — it loads one first, and reports failure if the store has none.
    @discardableResult
    func purchase() async -> PurchaseOutcome {
        guard !isPurchasing else { return .busy }
        isPurchasing = true
        defer { isPurchasing = false }

        guard let product = await loadProduct() else {
            return .failed(Self.unavailableMessage)
        }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
                // `handle` only flips `isPro` for a verified transaction, so
                // this reads the real outcome rather than assuming success.
                // A purchase that fails Apple's signature check lands here.
                return isPro
                    ? .purchased
                    : .failed(Self.unavailableMessage)
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed(Self.unavailableMessage)
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// The manual fallback for a reinstall or a new iPhone. `AppStore.sync()`
    /// asks for the Apple Account password, so it is a deliberate user action
    /// and never something we run on our own — the automatic path is
    /// `refresh()` at launch, which needs no sign-in.
    ///
    /// A failed sync reports failure rather than falling through to a reading
    /// of the entitlement it never refreshed: "nothing to restore" must mean
    /// the store answered and said so.
    @discardableResult
    func restore() async -> RestoreOutcome {
        guard !isRestoring else { return .busy }
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            // Backing out of the sign-in sheet is not a failure to report.
            return .cancelled
        } catch {
            return .failed(error.localizedDescription)
        }
        await refresh()
        return isPro ? .restored : .nothingToRestore
    }

    /// Finishes a verified transaction and re-reads the entitlement. Finishing
    /// is what stops StoreKit replaying the transaction on every launch, so it
    /// happens for every verified transaction — including revocations, where
    /// the re-read is what takes Pro away.
    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refresh()
    }
}
