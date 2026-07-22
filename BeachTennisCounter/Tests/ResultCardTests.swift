import XCTest
@testable import BeachTennisCounter

/// The Cartão de Resultado seam: a stored match plus a watermark flag in,
/// everything the card displays out. No rendering, no share sheet — those are
/// the thin shell around this model.
final class ResultCardTests: XCTestCase {

    private func setHistoryData(_ records: [SetRecord]) -> Data {
        (try? JSONEncoder().encode(records)) ?? Data()
    }

    private func makeMatch(
        date: Date = Date(timeIntervalSince1970: 1_700_000_000),
        setScoreA: Int = 6,
        setScoreB: Int = 3,
        setsWonA: Int = 0,
        setsWonB: Int = 0,
        winner: String = "a",
        duration: TimeInterval = 3_723,
        setHistory: [SetRecord] = [],
        matchTypeRaw: String = "beachTennis",
        teamAName: String = "",
        teamBName: String = ""
    ) -> StoredMatch {
        StoredMatch(
            date: date,
            setScoreA: setScoreA,
            setScoreB: setScoreB,
            setsWonA: setsWonA,
            setsWonB: setsWonB,
            winner: winner,
            duration: duration,
            setHistoryData: setHistoryData(setHistory),
            matchTypeRaw: matchTypeRaw,
            teamAName: teamAName,
            teamBName: teamBName
        )
    }

    // MARK: - Team labels

    func test_teamLabels_useStoredNames() {
        let card = ResultCard(match: makeMatch(teamAName: "Renan", teamBName: "Visitors"))

        XCTAssertEqual(card.teamAName, "Renan")
        XCTAssertEqual(card.teamBName, "Visitors")
    }

    func test_teamLabels_unnamedMatch_fallsBackToSlotLabels() {
        let card = ResultCard(match: makeMatch())

        XCTAssertEqual(card.teamAName, Team.a.displayName)
        XCTAssertEqual(card.teamBName, Team.b.displayName)
    }

    // MARK: - Score line, beach tennis

    /// Beach tennis has no sets: the games count is the score, and the label
    /// follows the beach "Set" convention in every language.
    func test_beachTennis_scoreIsGamesLabelledSets() {
        let card = ResultCard(match: makeMatch(setScoreA: 6, setScoreB: 4))

        XCTAssertEqual(card.scoreA, 6)
        XCTAssertEqual(card.scoreB, 4)
        XCTAssertEqual(card.scoreUnitLabel, MatchType.beachTennis.gamesSectionTitle)
        XCTAssertNil(card.setBreakdown)
    }

    /// A beach match never shows a per-set breakdown, even if a set record
    /// somehow rode along in the stored data.
    func test_beachTennis_ignoresSetHistory() {
        let card = ResultCard(match: makeMatch(
            setHistory: [SetRecord(setNumber: 1, gamesA: 6, gamesB: 4, winner: .a, isTiebreak: false)]
        ))

        XCTAssertNil(card.setBreakdown)
    }

    // MARK: - Score line, tennis

    func test_tennis_scoreIsSetsWithPerSetGames() {
        let card = ResultCard(match: makeMatch(
            setScoreA: 0,
            setScoreB: 0,
            setsWonA: 2,
            setsWonB: 1,
            duration: 3_723,
            setHistory: [
                SetRecord(setNumber: 1, gamesA: 6, gamesB: 4, winner: .a, isTiebreak: false),
                SetRecord(setNumber: 2, gamesA: 3, gamesB: 6, winner: .b, isTiebreak: false),
                SetRecord(setNumber: 3, gamesA: 10, gamesB: 8, winner: .a, isTiebreak: true)
            ],
            matchTypeRaw: "tennis"
        ))

        XCTAssertEqual(card.scoreA, 2)
        XCTAssertEqual(card.scoreB, 1)
        XCTAssertEqual(card.scoreUnitLabel, MatchType.setsSectionTitle)
        XCTAssertEqual(card.setBreakdown, "6-4  3-6  10-8")
    }

    /// A tennis match abandoned inside the first set has no set won by anyone;
    /// the card falls back to the games in play rather than showing "0 – 0".
    func test_tennis_noSetsWon_fallsBackToGames() {
        let card = ResultCard(match: makeMatch(
            setScoreA: 4,
            setScoreB: 2,
            matchTypeRaw: "tennis"
        ))

        XCTAssertEqual(card.scoreA, 4)
        XCTAssertEqual(card.scoreB, 2)
        XCTAssertEqual(card.scoreUnitLabel, MatchType.tennis.gamesSectionTitle)
        XCTAssertNil(card.setBreakdown)
    }

    // MARK: - Winner

    func test_winner_isTheStoredSide() {
        let card = ResultCard(match: makeMatch(winner: "b", teamAName: "Renan", teamBName: "Visitors"))

        XCTAssertEqual(card.winner, .b)
        XCTAssertEqual(card.teamBName, "Visitors")
    }

    /// A match whose stored winner names no known side highlights nobody
    /// rather than inventing a champion.
    func test_winner_unrecognizedSide_isNil() {
        let card = ResultCard(match: makeMatch(winner: ""))

        XCTAssertNil(card.winner)
    }

    // MARK: - Sport, date, duration

    func test_sportName_followsMatchType() {
        XCTAssertEqual(ResultCard(match: makeMatch()).sportName, MatchType.beachTennis.displayName)
        XCTAssertEqual(
            ResultCard(match: makeMatch(matchTypeRaw: "tennis")).sportName,
            MatchType.tennis.displayName
        )
    }

    func test_dateText_isTheMatchDate() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let card = ResultCard(match: makeMatch(date: date))

        XCTAssertEqual(card.dateText, date.formatted(date: .abbreviated, time: .shortened))
    }

    /// The card carries the duration in hours and minutes — unlike the history
    /// screen's "62:03", a card is shared with no "Duration" label beside it.
    func test_durationText_isHoursAndMinutes() {
        let card = ResultCard(match: makeMatch(duration: 3_723))

        XCTAssertEqual(
            card.durationText,
            Duration.seconds(3_723).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
        )
    }

    // MARK: - Watermark

    func test_watermark_presentByDefault_andNamesTheApp() {
        let card = ResultCard(match: makeMatch())

        XCTAssertEqual(card.watermark, ResultCard.appWatermark)
        XCTAssertFalse(ResultCard.appWatermark.isEmpty)
    }

    /// The watermark-free card is the Pro payoff in the following release; the
    /// model already takes the flag so nothing else has to change then.
    func test_watermark_absentWhenSuppressed() {
        let card = ResultCard(match: makeMatch(), showsWatermark: false)

        XCTAssertNil(card.watermark)
    }

    // MARK: - Way back to the app

    /// The shared message is what makes the watermark actionable: a viewer in a
    /// WhatsApp group taps the link instead of guessing the app's name.
    func test_shareMessage_carriesTheAppStoreLink() {
        XCTAssertTrue(
            ResultCard.shareMessage.contains(ResultCard.appStoreURL.absoluteString),
            "The share text must carry the App Store URL verbatim"
        )
    }

    /// A locale-free App Store path lets the store redirect each viewer to
    /// their own storefront; the URL is a constant, never translated.
    func test_appStoreURL_isLocaleFreeAndConstant() {
        XCTAssertEqual(
            ResultCard.appStoreURL.absoluteString,
            "https://apps.apple.com/app/id6765569699"
        )
    }

    /// The URL is not the whole message — a bare link reads as spam, and the
    /// sentence around it is the part the String Catalog owns.
    func test_shareMessage_saysSomethingBesidesTheURL() {
        let withoutURL = ResultCard.shareMessage
            .replacingOccurrences(of: ResultCard.appStoreURL.absoluteString, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertFalse(withoutURL.isEmpty)
    }
}
