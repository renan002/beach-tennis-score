import XCTest
@testable import BeachTennisCounter

/// The `TeamName` rules at their own seam. The resolve rule is already covered
/// at the higher, user-facing seams — `MatchStateTeamNameTests` and
/// `StoredMatchDisplayTests` — so what is new here is the cap and the commit
/// rule, which until now lived inside the iPhone Settings screen where nothing
/// could reach them.
final class TeamNameTests: XCTestCase {

    // MARK: - capped

    func test_capped_shortName_unchanged() {
        XCTAssertEqual(TeamName.capped("Renan"), "Renan")
    }

    func test_capped_exactlyMaxLength_unchanged() {
        let name = String(repeating: "a", count: TeamName.maxLength)
        XCTAssertEqual(TeamName.capped(name), name)
    }

    func test_capped_overMaxLength_truncatesToMax() {
        let name = String(repeating: "a", count: TeamName.maxLength + 5)
        let capped = TeamName.capped(name)
        XCTAssertEqual(capped.count, TeamName.maxLength)
        XCTAssertEqual(capped, String(repeating: "a", count: TeamName.maxLength))
    }

    func test_capped_countsGraphemeClusters_emojiIsOneCharacter() {
        // Twelve emoji are twelve characters, so the name survives the cap whole
        // even though it is far longer in unicode scalars or UTF-8 bytes.
        let name = String(repeating: "🏖️", count: TeamName.maxLength)
        XCTAssertEqual(TeamName.capped(name), name)
    }

    func test_capped_countsGraphemeClusters_thirteenEmojiLosesOne() {
        let name = String(repeating: "🎾", count: TeamName.maxLength + 1)
        XCTAssertEqual(TeamName.capped(name), String(repeating: "🎾", count: TeamName.maxLength))
    }

    func test_capped_emptyName_staysEmpty() {
        XCTAssertEqual(TeamName.capped(""), "")
    }

    // MARK: - committed

    func test_committed_trimsSurroundingWhitespace() {
        XCTAssertEqual(TeamName.committed("  Renan  "), "Renan")
    }

    func test_committed_trimsNewlines() {
        XCTAssertEqual(TeamName.committed("\nRenan\n"), "Renan")
    }

    func test_committed_whitespaceOnly_collapsesToEmpty() {
        XCTAssertEqual(TeamName.committed("   "), "")
    }

    func test_committed_keepsInnerWhitespace() {
        XCTAssertEqual(TeamName.committed(" Renan e Bruno "), "Renan e Bruno")
    }

    func test_committed_alreadyCanonical_unchanged() {
        XCTAssertEqual(TeamName.committed("Renan"), "Renan")
    }

    // MARK: - resolved

    func test_resolved_nonEmptyName_wins() {
        XCTAssertEqual(TeamName.resolved("Renan", for: .a), "Renan")
        XCTAssertEqual(TeamName.resolved("Visitors", for: .b), "Visitors")
    }

    func test_resolved_emptyName_fallsBackToSlotLabel() {
        XCTAssertEqual(TeamName.resolved("", for: .a), Team.a.displayName)
        XCTAssertEqual(TeamName.resolved("", for: .b), Team.b.displayName)
    }

    func test_resolved_whitespaceOnlyName_countsAsNoName() {
        XCTAssertEqual(TeamName.resolved("   ", for: .a), Team.a.displayName)
    }
}
