import XCTest
@testable import BeachTennisCounter

/// The one testable seam of the Pro plumbing: the local StoreKit configuration
/// the simulator demo runs against must describe the same product the app asks
/// StoreKit for. Nothing here mocks StoreKit — entitlement state itself is
/// StoreKit's to report, and the `isPro` mapping is verified by running the
/// app (see the ticket's simulator demo).
///
/// It catches the failure that is otherwise silent and expensive: rename the
/// product id in one place and the purchase sheet just shows no product, with
/// no error anywhere.
final class ProEntitlementTests: XCTestCase {

    /// The configuration is copied into the test bundle as a resource by the
    /// test target, so this reads the very file the schemes point at.
    private func storeKitConfiguration() throws -> [String: Any] {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "Pro", withExtension: "storekit"),
            "Pro.storekit is not in the test bundle — check the test target's resources"
        )
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        return try XCTUnwrap(object as? [String: Any])
    }

    private func products() throws -> [[String: Any]] {
        try XCTUnwrap(storeKitConfiguration()["products"] as? [[String: Any]])
    }

    func testConfigurationDeclaresExactlyOneProduct() throws {
        XCTAssertEqual(try products().count, 1)
    }

    func testConfiguredProductIDMatchesTheOneTheAppRequests() throws {
        let product = try XCTUnwrap(products().first)
        XCTAssertEqual(product["productID"] as? String, ProEntitlement.productID)
    }

    /// Lifetime unlock, not a subscription and not re-buyable (ADR 0004).
    func testConfiguredProductIsNonConsumable() throws {
        let product = try XCTUnwrap(products().first)
        XCTAssertEqual(product["type"] as? String, "NonConsumable")
    }

    // MARK: - The dark-build rule

    /// `isPro` is "you own it, **or** it isn't for sale". These four cases are
    /// the whole rule, and they are reachable from a `Debug` test bundle — where
    /// `PRO_ON_SALE` is on — precisely because the rule is a pure function of
    /// both values rather than a read of the compilation condition. The dark
    /// half is the half that ships.

    func testOwningProUnlocksItWhileProIsOnSale() {
        XCTAssertTrue(ProEntitlement.isPro(ownsPro: true, proOnSale: true))
    }

    func testNotOwningProLocksItWhileProIsOnSale() {
        XCTAssertFalse(ProEntitlement.isPro(ownsPro: false, proOnSale: true))
    }

    /// The shipped case for 1.4/1.5: nobody has bought anything, Pro is dark,
    /// and every Pro feature is therefore free — today's behaviour exactly.
    func testProIsFreeForEveryoneWhileItIsNotOnSale() {
        XCTAssertTrue(ProEntitlement.isPro(ownsPro: false, proOnSale: false))
    }

    /// A buyer from a future flag-on release who then installs an older dark
    /// build still gets Pro. Owning it can never take it away.
    func testOwningProStillUnlocksItWhileItIsNotOnSale() {
        XCTAssertTrue(ProEntitlement.isPro(ownsPro: true, proOnSale: false))
    }

    // MARK: - The wiring

    /// The rule above passes whether or not `PRO_ON_SALE` is ever wired up, so
    /// pin the wiring itself: the condition must be on in `Debug` and `Dev` and
    /// **absent** from `Release`, which is what makes a shipped build dark.
    ///
    /// Read from the checked-in `project.pbxproj` rather than `project.yml`,
    /// because the pbxproj is what Xcode actually builds — the same reason
    /// `scripts/validate-release-version.sh` reads it. A regeneration that
    /// dropped the setting would leave `project.yml` looking correct.
    /// `Release` is expected to have *no* `SWIFT_ACTIVE_COMPILATION_CONDITIONS`
    /// entry at all — a condition is present or it is not — so the assertion is
    /// on the exact set of configurations that define one. That shape also
    /// fails loudly if the pbxproj stops looking the way this walk expects,
    /// rather than quietly vouching for nothing.
    func testProOnSaleIsWiredOnInDebugAndDevAndAbsentFromRelease() throws {
        let conditions = try compilationConditionsPerConfiguration()

        XCTAssertEqual(
            Set(conditions.keys), ["Debug", "Dev"],
            "Exactly the two debug configurations should define compilation "
                + "conditions. Release defining any means a shipped build could "
                + "carry PRO_ON_SALE; finding neither means this walk broke."
        )
        XCTAssertTrue(conditions["Debug"]?.contains("PRO_ON_SALE") == true)
        XCTAssertTrue(conditions["Dev"]?.contains("PRO_ON_SALE") == true)

        let pbxproj = try projectFileContents()
        XCTAssertTrue(
            pbxproj.contains("name = Release;"),
            "No Release configuration in the pbxproj — the check above proves "
                + "nothing about the configuration we actually ship"
        )
    }

    /// Restating `DEBUG` alongside `PRO_ON_SALE` is load-bearing: setting the
    /// key at all replaces XcodeGen's automatic value for a debug-type config.
    /// Drop it and `#if DEBUG` goes dark project-wide, silently.
    func testDebugConfigurationsStillDefineDEBUG() throws {
        let conditions = try compilationConditionsPerConfiguration()
        XCTAssertTrue(conditions["Debug"]?.contains("DEBUG") == true)
        XCTAssertTrue(conditions["Dev"]?.contains("DEBUG") == true)
    }

    /// The `SWIFT_ACTIVE_COMPILATION_CONDITIONS` value of each *project-level*
    /// build configuration, keyed by configuration name. Target-level
    /// configurations do not set the key, so scanning every occurrence and
    /// pairing it with the nearest enclosing `name = …` is enough.
    private func compilationConditionsPerConfiguration() throws -> [String: String] {
        let source = try projectFileContents()

        var conditions: [String: String] = [:]
        var pending: String?
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("SWIFT_ACTIVE_COMPILATION_CONDITIONS") {
                pending = trimmed
            } else if let value = pending, trimmed.hasPrefix("name = ") {
                let name = trimmed
                    .dropFirst("name = ".count)
                    .replacingOccurrences(of: ";", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
                conditions[name] = value
                pending = nil
            }
        }
        return conditions
    }

    private func projectFileContents() throws -> String {
        let pbxproj = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // BeachTennisCounter/
            .appendingPathComponent("BeachTennisCounter.xcodeproj/project.pbxproj")
        return try String(contentsOf: pbxproj, encoding: .utf8)
    }

    /// The watch never links StoreKit: no purchase UI, no entitlement
    /// awareness. Enforced here rather than left to review because the
    /// temptation — putting the flag in `Shared/` where both targets see it —
    /// compiles fine and only fails App Review's watch build much later.
    func testStoreKitIsNotImportedOutsideTheiOSTarget() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // BeachTennisCounter/
        for directory in ["watchOS", "Shared"] {
            let root = repoRoot.appendingPathComponent(directory)
            let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }
                .filter { $0.pathExtension == "swift" } ?? []
            XCTAssertFalse(files.isEmpty, "No Swift files found under \(directory)")
            for file in files {
                let source = try String(contentsOf: file, encoding: .utf8)
                XCTAssertFalse(
                    source.contains("import StoreKit"),
                    "\(directory)/\(file.lastPathComponent) imports StoreKit — it is compiled into the watch target"
                )
            }
        }
    }
}
