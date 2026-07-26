import XCTest
@testable import BeachTennisCounter

/// The dark build's visible half: with `FeatureFlags.proOnSale` off there must be
/// no Pro copy, no purchase affordance and no paywall anywhere on the phone.
///
/// SwiftUI bodies are not unit-testable here and the bundle compiles under
/// `Debug`, where the flag is **on** — so running the views could never observe
/// the dark state anyway. These are structural tests over the sources instead,
/// the same idiom as `ProEntitlementTests.testStoreKitIsNotImportedOutsideTheiOSTarget`.
///
/// What they actually protect: not that today's guard exists — a human reading
/// `SettingsView` can see that — but that a *future* purchase surface cannot be
/// added somewhere unguarded and ship dark-in-name-only. That is the failure
/// mode nobody notices, because `Debug` and `Dev` both look correct.
final class ProSurfaceTests: XCTestCase {

    /// Vocabulary that only ever belongs to the act of selling Pro. Deliberately
    /// excludes `ProEntitlement`, `isPro` and `ownsPro`: reading the entitlement
    /// is not selling, and #78's gates will read `isPro` all over the app while
    /// staying invisible in a dark build.
    private static let purchaseVocabulary = [
        "ProPurchaseSheet",
        "RestorePurchasesButton",
        "Unlock Pro",
    ]

    /// The files allowed to speak that vocabulary. The first two *are* the
    /// purchase surface; `SettingsView` is its one entry point, and is required
    /// below to guard it.
    private static let allowed: Set<String> = [
        "ProPurchaseSheet.swift",
        "RestorePurchasesButton.swift",
        "SettingsView.swift",
    ]

    func testNothingOutsideTheKnownSurfaceMentionsBuyingPro() throws {
        var offenders: [String] = []
        for file in try iOSSwiftFiles() {
            guard !Self.allowed.contains(file.lastPathComponent) else { continue }
            let source = try code(in: file)
            if Self.purchaseVocabulary.contains(where: source.contains) {
                offenders.append(file.lastPathComponent)
            }
        }
        XCTAssertEqual(
            offenders, [],
            "A purchase surface appeared outside the files that own one. Either "
                + "guard it with FeatureFlags.proOnSale and add it to `allowed`, "
                + "or it will ship visible in a build where Pro is not on sale."
        )
    }

    /// The one guard. `SettingsView` holds the only entry to `ProPurchaseSheet` —
    /// `showProSheet` cannot become `true` without the button inside the gated
    /// section — so the sheet and the Restore button need no guards of their own,
    /// and this is the single line whose deletion would make a dark build sell.
    func testSettingsGatesTheProSectionOnTheFlag() throws {
        let settings = try iOSSwiftFiles()
            .first { $0.lastPathComponent == "SettingsView.swift" }
        // Comments stripped, so a doc comment mentioning the guard can never
        // stand in for the guard.
        let source = try code(in: try XCTUnwrap(settings))

        XCTAssertTrue(
            source.contains("if FeatureFlags.proOnSale"),
            "SettingsView no longer gates its Pro section on the flag — a dark "
                + "build would show Unlock Pro, the pitch and Restore"
        )
    }

    /// The purchase surface must not be reachable from a second place that this
    /// suite would then have to learn about. `MatchListView` presents Settings
    /// and Statistics and is the obvious place for a paywall to grow.
    func testTheOnlyPresenterOfThePurchaseSheetIsSettings() throws {
        for file in try iOSSwiftFiles() where file.lastPathComponent != "SettingsView.swift" {
            XCTAssertFalse(
                try code(in: file).contains("ProPurchaseSheet()"),
                "\(file.lastPathComponent) presents ProPurchaseSheet — the sheet "
                    + "has no guard of its own because Settings was its only entry"
            )
        }
    }

    /// A file's source with `//` comment lines dropped. Prose *about* the
    /// purchase surface is not a purchase surface — `ProEntitlement` quotes the
    /// "Unlock Pro" label while explaining which reading its callers want, and
    /// that must not read as an offence. Line comments only; the codebase uses
    /// no block comments, and a scanner that tried to parse them would be
    /// claiming more rigour than it has.
    private func code(in file: URL) throws -> String {
        try String(contentsOf: file, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private func iOSSwiftFiles() throws -> [URL] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // BeachTennisCounter/
            .appendingPathComponent("iOS")
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []
        XCTAssertFalse(files.isEmpty, "No Swift files found under iOS/")
        return files
    }
}
