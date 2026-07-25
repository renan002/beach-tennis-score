import Foundation
import SwiftData

/// The single authority for where the live Match History store lives and how it
/// is opened. Opening, quarantining and (later) restoring all resolve the
/// location through here, so they can never disagree about where the store is.
enum LiveStore {
    /// Info.plist key publishing the App Group this build's store lives in.
    static let appGroupIdentifierKey = "AppGroupIdentifier"
    static let storeName = "default.store"

    /// The App Group this build's store lives in, read from Info.plist rather
    /// than hardcoded. `project.yml` sets it to `group.$(PRODUCT_BUNDLE_IDENTIFIER)`,
    /// so a flavored bundle id carries its own group and the literal here can
    /// never disagree with the one the app is entitled to.
    ///
    /// A missing or empty key is a build misconfiguration, not a runtime
    /// condition — every build that gets this far has an Info.plist we
    /// generated — so it fails loudly on first launch rather than silently
    /// resolving to the wrong store.
    static let appGroupIdentifier: String = {
        guard let identifier = Bundle.main
            .object(forInfoDictionaryKey: appGroupIdentifierKey) as? String,
              !identifier.isEmpty else {
            fatalError("Info.plist has no non-empty \(appGroupIdentifierKey): this build is misconfigured.")
        }
        return identifier
    }()

    /// The directory the live store actually lives in: the App Group
    /// container's Application Support directory. SwiftData has always placed
    /// `default.store` here given the app's group entitlement, so resolving it
    /// explicitly changes nothing about the store's location — it only stops
    /// the recovery path from acting on the app sandbox, where the store has
    /// never lived (#48).
    static var directory: URL {
        if let group = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return group.appending(path: "Library/Application Support")
        }
        // Without the App Group entitlement (e.g. an unsigned test host)
        // SwiftData itself falls back to the app sandbox; match that so we
        // resolve to wherever the implicit default store would have lived
        // rather than crashing or orphaning it. This case is indistinguishable
        // at runtime from an entitlement that disagrees with
        // `appGroupIdentifier`, which is why that disagreement is prevented at
        // the build level instead — both sides derive from the bundle id.
        return .applicationSupportDirectory
    }

    /// Opens the store in `directory`, quarantining an unopenable store and
    /// starting fresh rather than crashing. Parameterized by directory so the
    /// app drives it against the real App Group container and tests drive it
    /// against a scratch location; `StoreRecovery` operates on that same
    /// directory, so the safety net always acts on the store the app uses.
    ///
    /// The container is pinned to an explicit `ModelConfiguration(url:)` rather
    /// than the implicit default — the capability Restore (#43) needs to read a
    /// Quarantined Store the same way — resolved to the store's current home so
    /// no existing Match History is orphaned.
    static func open(in directory: URL) -> ModelContainer {
        // The App Group's Application Support directory may not exist on first
        // launch, and an explicit store URL will not create it for us.
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)

        let configuration = ModelConfiguration(url: directory.appending(path: storeName))
        do {
            return try ModelContainer(for: StoredMatch.self, configurations: configuration)
        } catch {
            // Store is unreadable (e.g. a schema migration failed). Quarantine
            // the SQLite files intact — never delete — and start fresh.
            StoreRecovery.quarantine(in: directory, reason: String(describing: error))
            do {
                return try ModelContainer(for: StoredMatch.self, configurations: configuration)
            } catch {
                // A second failure in a row: fail visibly rather than risk
                // silently destroying data.
                fatalError("ModelContainer unrecoverable: \(error)")
            }
        }
    }
}
