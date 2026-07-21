import XCTest
@testable import BeachTennisCounter

final class MatchResultPayloadTests: XCTestCase {

    private func makePayload(
        matchId: UUID = UUID(),
        setScoreA: Int = 6, setScoreB: Int = 3,
        setsWonA: Int = 0, setsWonB: Int = 0,
        winner: Team = .a, duration: TimeInterval = 3600,
        date: Date = Date(timeIntervalSince1970: 1_000_000),
        gameHistory: [GameRecord] = [],
        setHistory: [SetRecord] = [],
        matchType: MatchType = .beachTennis,
        teamAName: String = "",
        teamBName: String = "",
        activeCalories: Double? = nil,
        avgHeartRate: Double? = nil
    ) -> MatchResultPayload {
        MatchResultPayload(matchId: matchId,
                           setScoreA: setScoreA, setScoreB: setScoreB,
                           setsWonA: setsWonA, setsWonB: setsWonB,
                           winner: winner, duration: duration,
                           date: date, gameHistory: gameHistory,
                           setHistory: setHistory, matchType: matchType,
                           teamAName: teamAName, teamBName: teamBName,
                           activeCalories: activeCalories, avgHeartRate: avgHeartRate)
    }

    // MARK: - Round-trip

    func test_roundtrip_scoresAndWinner() {
        let payload = makePayload(setScoreA: 6, setScoreB: 3, winner: .a)
        let decoded = MatchResultPayload.from(payload.toDictionary())
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.setScoreA, 6)
        XCTAssertEqual(decoded?.setScoreB, 3)
        XCTAssertEqual(decoded?.winner, .a)
    }

    func test_roundtrip_duration() {
        let payload = makePayload(duration: 4567.89)
        let decoded = MatchResultPayload.from(payload.toDictionary())
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.duration, 4567.89, accuracy: 0.001)
    }

    func test_roundtrip_date() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let payload = makePayload(date: date)
        let decoded = MatchResultPayload.from(payload.toDictionary())
        XCTAssertNotNil(decoded?.date)
        XCTAssertEqual(decoded!.date.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 1)
    }

    func test_roundtrip_gameHistory() {
        let record = GameRecord(gameNumber: 1, setScoreA: 1, setScoreB: 0,
                                winner: .a, isTiebreak: false, gameScoreDisplay: "40–30")
        let payload = makePayload(gameHistory: [record])
        let decoded = MatchResultPayload.from(payload.toDictionary())
        XCTAssertEqual(decoded?.gameHistory.count, 1)
        XCTAssertEqual(decoded?.gameHistory.first?.gameScoreDisplay, "40–30")
        XCTAssertEqual(decoded?.gameHistory.first?.winner, .a)
        XCTAssertFalse(decoded?.gameHistory.first?.isTiebreak ?? true)
    }

    func test_roundtrip_tiebreakGameRecord() {
        let record = GameRecord(gameNumber: 13, setScoreA: 7, setScoreB: 6,
                                winner: .b, isTiebreak: true, gameScoreDisplay: "7–5")
        let payload = makePayload(winner: .b, gameHistory: [record])
        let decoded = MatchResultPayload.from(payload.toDictionary())
        XCTAssertTrue(decoded?.gameHistory.first?.isTiebreak == true)
        XCTAssertEqual(decoded?.gameHistory.first?.gameScoreDisplay, "7–5")
    }

    func test_roundtrip_emptyGameHistory() {
        let payload = makePayload(gameHistory: [])
        let decoded = MatchResultPayload.from(payload.toDictionary())
        XCTAssertEqual(decoded?.gameHistory.count, 0)
    }

    func test_roundtrip_matchId() {
        let payload = makePayload()
        let decoded = MatchResultPayload.from(payload.toDictionary())
        XCTAssertEqual(decoded?.matchId, payload.matchId)
    }

    func test_from_missingMatchIdStillDecodes() {
        var dict = makePayload().toDictionary()
        dict.removeValue(forKey: WatchMessageKey.matchId)
        XCTAssertNotNil(MatchResultPayload.from(dict))
    }

    func test_from_invalidMatchIdStillDecodes() {
        var dict = makePayload().toDictionary()
        dict[WatchMessageKey.matchId] = "not-a-uuid"
        XCTAssertNotNil(MatchResultPayload.from(dict))
    }

    // MARK: - Team Names

    func test_roundtrip_teamNames() {
        let payload = makePayload(teamAName: "Renan", teamBName: "Visitors")
        let decoded = MatchResultPayload.from(payload.toDictionary())
        XCTAssertEqual(decoded?.teamAName, "Renan")
        XCTAssertEqual(decoded?.teamBName, "Visitors")
    }

    func test_from_missingTeamNames_decodeToEmptyStrings() {
        // An old watch never wrote the name keys; the result must still decode
        // (never nil), with names materializing empty rather than absent.
        var dict = makePayload(teamAName: "Renan", teamBName: "Visitors").toDictionary()
        dict.removeValue(forKey: WatchMessageKey.teamAName)
        dict.removeValue(forKey: WatchMessageKey.teamBName)
        let decoded = MatchResultPayload.from(dict)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.teamAName, "")
        XCTAssertEqual(decoded?.teamBName, "")
    }

    func test_from_emptyTeamNames_roundTripEmpty() {
        let decoded = MatchResultPayload.from(makePayload().toDictionary())
        XCTAssertEqual(decoded?.teamAName, "")
        XCTAssertEqual(decoded?.teamBName, "")
    }

    // MARK: - Workout stats

    func test_roundtrip_workoutStats() {
        let payload = makePayload(activeCalories: 245.6, avgHeartRate: 142.3)
        let decoded = MatchResultPayload.from(payload.toDictionary())
        XCTAssertEqual(decoded?.activeCalories ?? 0, 245.6, accuracy: 0.001)
        XCTAssertEqual(decoded?.avgHeartRate ?? 0, 142.3, accuracy: 0.001)
    }

    func test_from_missingWorkoutStats_decodeToNil() {
        // A denied / monitoring-off / old-watch payload omits the keys entirely;
        // the result must still decode, with the stats materializing nil.
        let dict = makePayload().toDictionary()
        XCTAssertNil(dict[WatchMessageKey.activeCalories])
        XCTAssertNil(dict[WatchMessageKey.avgHeartRate])
        let decoded = MatchResultPayload.from(dict)
        XCTAssertNotNil(decoded)
        XCTAssertNil(decoded?.activeCalories)
        XCTAssertNil(decoded?.avgHeartRate)
    }

    func test_toDictionary_omitsNilWorkoutStats() {
        let dict = makePayload(activeCalories: nil, avgHeartRate: nil).toDictionary()
        XCTAssertFalse(dict.keys.contains(WatchMessageKey.activeCalories))
        XCTAssertFalse(dict.keys.contains(WatchMessageKey.avgHeartRate))
    }

    // MARK: - Codable round-trip (local persistence)

    func test_codableRoundtrip_preservesFields() {
        let payload = makePayload(setScoreA: 7, setScoreB: 6, winner: .b, duration: 1234)
        let data = try! JSONEncoder().encode(payload)
        let decoded = try! JSONDecoder().decode(MatchResultPayload.self, from: data)
        XCTAssertEqual(decoded.matchId, payload.matchId)
        XCTAssertEqual(decoded.setScoreA, 7)
        XCTAssertEqual(decoded.setScoreB, 6)
        XCTAssertEqual(decoded.winner, .b)
        XCTAssertEqual(decoded.duration, 1234, accuracy: 0.001)
    }

    // MARK: - Missing fields

    func test_from_nilOnMissingSetScoreA() {
        var dict = makePayload().toDictionary()
        dict.removeValue(forKey: WatchMessageKey.setScoreA)
        XCTAssertNil(MatchResultPayload.from(dict))
    }

    func test_from_nilOnMissingSetScoreB() {
        var dict = makePayload().toDictionary()
        dict.removeValue(forKey: WatchMessageKey.setScoreB)
        XCTAssertNil(MatchResultPayload.from(dict))
    }

    func test_from_nilOnMissingWinner() {
        var dict = makePayload().toDictionary()
        dict.removeValue(forKey: WatchMessageKey.winner)
        XCTAssertNil(MatchResultPayload.from(dict))
    }

    func test_from_nilOnInvalidWinner() {
        var dict = makePayload().toDictionary()
        dict[WatchMessageKey.winner] = "c"
        XCTAssertNil(MatchResultPayload.from(dict))
    }

    func test_from_nilOnMissingDuration() {
        var dict = makePayload().toDictionary()
        dict.removeValue(forKey: WatchMessageKey.duration)
        XCTAssertNil(MatchResultPayload.from(dict))
    }

    func test_from_nilOnMissingDate() {
        var dict = makePayload().toDictionary()
        dict.removeValue(forKey: WatchMessageKey.date)
        XCTAssertNil(MatchResultPayload.from(dict))
    }

    func test_from_nilOnEmptyDict() {
        XCTAssertNil(MatchResultPayload.from([:]))
    }

    // MARK: - Corrupt game history falls back to empty

    func test_from_corruptGameHistoryFallsBackToEmpty() {
        var dict = makePayload().toDictionary()
        dict[WatchMessageKey.gameHistory] = Data([0x00, 0xFF])
        let decoded = MatchResultPayload.from(dict)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.gameHistory.count, 0)
    }
}
