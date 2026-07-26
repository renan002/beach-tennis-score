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
