import XCTest
@testable import BeachTennisCounter

/// The Match History sport filter: an optional `MatchType` where `nil` means
/// All. Comparing types instead of sport string literals is what keeps a typo
/// from silently emptying the screen.
final class MatchHistoryFilterTests: XCTestCase {

    private func makeMatch(_ type: MatchType) -> StoredMatch {
        StoredMatch(
            date: Date(),
            setScoreA: 6,
            setScoreB: 3,
            winner: "a",
            duration: 600,
            matchTypeRaw: type.rawValue
        )
    }

    private lazy var beach = makeMatch(.beachTennis)
    private lazy var tennis = makeMatch(.tennis)
    private var all: [StoredMatch] { [beach, tennis] }

    func test_nilFilter_keepsEverything() {
        XCTAssertEqual(StoredMatch.filtered(all, by: nil).map(\.matchType), [.beachTennis, .tennis])
    }

    func test_beachTennisFilter_keepsOnlyBeachMatches() {
        XCTAssertEqual(StoredMatch.filtered(all, by: .beachTennis).map(\.matchType), [.beachTennis])
    }

    func test_tennisFilter_keepsOnlyTennisMatches() {
        XCTAssertEqual(StoredMatch.filtered(all, by: .tennis).map(\.matchType), [.tennis])
    }

    /// A stored value that no longer names a `MatchType` reads as beach tennis
    /// everywhere else in the app — the filter must agree, or such a match
    /// would be unreachable from any of the three menu options.
    func test_unrecognizedStoredType_filtersAsBeachTennis() {
        let corrupt = StoredMatch(
            date: Date(),
            setScoreA: 6,
            setScoreB: 3,
            winner: "a",
            duration: 600,
            matchTypeRaw: "padel"
        )

        XCTAssertEqual(StoredMatch.filtered([corrupt], by: .beachTennis).count, 1)
        XCTAssertTrue(StoredMatch.filtered([corrupt], by: .tennis).isEmpty)
    }
}
