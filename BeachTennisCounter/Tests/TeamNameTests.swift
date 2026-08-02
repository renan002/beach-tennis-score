import XCTest
@testable import BeachTennisCounter

/// The Team Name rules at their own seam. The resolver is also covered through
/// the models' accessors (`MatchStateTeamNameTests`, `StoredMatchDisplayTests`) —
/// the higher, user-facing seam, left untouched by this move. What is new here
/// is the cap and the trim, which used to live in `SettingsView` where no test
/// could reach them.
final class TeamNameTests: XCTestCase {

    // MARK: - Resolution

    func test_resolve_nonEmptyName_wins() {
        XCTAssertEqual(TeamName.resolve("Renan", for: .a), "Renan")
        XCTAssertEqual(TeamName.resolve("Visitors", for: .b), "Visitors")
    }

    func test_resolve_emptyName_fallsBackToSideLabel() {
        XCTAssertEqual(TeamName.resolve("", for: .a), Team.a.displayName)
        XCTAssertEqual(TeamName.resolve("", for: .b), Team.b.displayName)
    }

    // MARK: - Cap

    func test_capped_shortName_isUnchanged() {
        XCTAssertEqual(TeamName.capped("Renan"), "Renan")
    }

    func test_capped_atLimit_isUnchanged() {
        let atLimit = String(repeating: "a", count: TeamName.maxLength)
        XCTAssertEqual(TeamName.capped(atLimit), atLimit)
    }

    func test_capped_overLimit_isTruncated() {
        let over = String(repeating: "a", count: TeamName.maxLength + 5)
        XCTAssertEqual(TeamName.capped(over).count, TeamName.maxLength)
    }

    /// The cap counts grapheme clusters, so the limit behaves the way it looks:
    /// twelve emoji are twelve characters, not however many scalars they encode.
    func test_capped_countsEmojiAsOneCharacterEach() {
        let twelveEmoji = String(repeating: "🎾", count: TeamName.maxLength)
        XCTAssertEqual(TeamName.capped(twelveEmoji), twelveEmoji)

        let thirteenEmoji = String(repeating: "🎾", count: TeamName.maxLength + 1)
        XCTAssertEqual(TeamName.capped(thirteenEmoji), twelveEmoji)
    }

    /// A family emoji is a single grapheme cluster made of several scalars —
    /// the case that separates counting characters from counting UTF-16 units.
    func test_capped_countsCombinedEmojiAsOneCharacter() {
        let family = "👨‍👩‍👧‍👦"
        XCTAssertEqual(TeamName.capped(family), family)
    }

    // MARK: - Commit

    func test_committed_stripsSurroundingWhitespace() {
        XCTAssertEqual(TeamName.committed("  Renan  "), "Renan")
        XCTAssertEqual(TeamName.committed("Renan\n"), "Renan")
    }

    func test_committed_keepsInnerWhitespace() {
        XCTAssertEqual(TeamName.committed(" Renan e Bruno "), "Renan e Bruno")
    }

    /// A name that is only spaces counts as no name at all — and, once
    /// committed, resolves to the localized side label.
    func test_committed_whitespaceOnly_collapsesToEmpty() {
        XCTAssertEqual(TeamName.committed("   "), "")
        XCTAssertEqual(TeamName.resolve(TeamName.committed("   "), for: .a), Team.a.displayName)
    }

    func test_committed_alreadyClean_isUnchanged() {
        XCTAssertEqual(TeamName.committed("Renan"), "Renan")
    }
}
