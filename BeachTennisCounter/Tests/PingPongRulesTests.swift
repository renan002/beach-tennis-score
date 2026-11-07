import XCTest
@testable import BeachTennisCounter

final class PingPongRulesTests: XCTestCase {

    // MARK: - Presets

    /// The three stable presets, pinned by both identity and knobs. These are
    /// what ships, so their numbers are the contract.
    func test_presets_haveStableIdentitiesAndKnobs() {
        XCTAssertEqual(PingPongRuleset.oficial.identifier, PingPongRuleset.oficialID)
        XCTAssertEqual(PingPongRuleset.oficial.pointsTarget, 11)
        XCTAssertEqual(PingPongRuleset.oficial.bestOf, 5)
        XCTAssertEqual(PingPongRuleset.oficial.serveMode, .every2)
        XCTAssertEqual(PingPongRuleset.oficial.gamesToWinMatch, 3)
        XCTAssertTrue(PingPongRuleset.oficial.isPreset)

        XCTAssertEqual(PingPongRuleset.classico.pointsTarget, 21)
        XCTAssertEqual(PingPongRuleset.classico.bestOf, 3)
        XCTAssertEqual(PingPongRuleset.classico.serveMode, .every5)
        XCTAssertEqual(PingPongRuleset.classico.gamesToWinMatch, 2)

        XCTAssertEqual(PingPongRuleset.rapido.pointsTarget, 11)
        XCTAssertEqual(PingPongRuleset.rapido.bestOf, 1)
        XCTAssertEqual(PingPongRuleset.rapido.serveMode, .every2)
        XCTAssertEqual(PingPongRuleset.rapido.gamesToWinMatch, 1)
    }

    /// Oficial is the factory default — the value stamped when nothing is
    /// configured.
    func test_defaultRuleset_isOficial() {
        let rules = Ruleset.preset(for: .pingPong)
        XCTAssertEqual(rules.sport, .pingPong)
        XCTAssertEqual(rules.pingPong, .oficial)
    }

    // MARK: - Valid targets

    /// Positive integer targets are playable, with no arbitrary 99 cap — 100 is
    /// a valid custom target.
    func test_isValid_anyPositiveTarget() {
        XCTAssertTrue(rules(target: 1).isValid)
        XCTAssertTrue(rules(target: 11).isValid)
        XCTAssertTrue(rules(target: 15).isValid)
        XCTAssertTrue(rules(target: 21).isValid)
        XCTAssertTrue(rules(target: 100).isValid)
    }

    func test_isValid_rejectsZeroAndNegativeTargets() {
        XCTAssertFalse(rules(target: 0).isValid)
        XCTAssertFalse(rules(target: -5).isValid)
    }

    /// Deuce pushes the arithmetic to 2×(target−1); a target whose bound would
    /// overflow Int must decode as invalid rather than trap. The safe ceiling
    /// is `Int.max/2 + 1`; anything larger fails the arithmetic-safety check.
    func test_isValid_rejectsArithmeticUnsafeTarget() {
        XCTAssertTrue(rules(target: Int.max / 2 + 1).isValid)
        XCTAssertFalse(rules(target: Int.max / 2 + 2).isValid)
        XCTAssertFalse(rules(target: Int.max).isValid)
    }

    // MARK: - Best-of

    func test_isValid_acceptsBestOfOneThreeFiveSeven() {
        for n in PingPongRuleset.validBestOf {
            XCTAssertTrue(rules(bestOf: n).isValid)
        }
    }

    func test_isValid_rejectsOtherBestOf() {
        XCTAssertFalse(rules(bestOf: 2).isValid)
        XCTAssertFalse(rules(bestOf: 4).isValid)
        XCTAssertFalse(rules(bestOf: 6).isValid)
        XCTAssertFalse(rules(bestOf: 9).isValid)
        XCTAssertFalse(rules(bestOf: 0).isValid)
    }

    func test_gamesToWinMatch_matchesTheBestOf() {
        XCTAssertEqual(rules(bestOf: 1).gamesToWinMatch, 1)
        XCTAssertEqual(rules(bestOf: 3).gamesToWinMatch, 2)
        XCTAssertEqual(rules(bestOf: 5).gamesToWinMatch, 3)
        XCTAssertEqual(rules(bestOf: 7).gamesToWinMatch, 4)
    }

    // MARK: - Win-by-2 is fixed

    func test_isValid_rejectsWinByTwoOff() {
        XCTAssertFalse(rules(winByTwo: false).isValid)
    }

    // MARK: - Codable round-trip and rejection

    func test_roundTrip_customRuleset_keepsKnobs() throws {
        var custom = rules(target: 15, bestOf: 5, serveMode: .every5)
        custom.name = "Custom 15"
        let data = try JSONEncoder().encode(custom)
        let decoded = try JSONDecoder().decode(PingPongRuleset.self, from: data)
        XCTAssertEqual(decoded, custom)
        XCTAssertEqual(decoded.identifier, custom.identifier)
        XCTAssertEqual(decoded.name, "Custom 15")
    }

    /// Decoding a stored ruleset applies the same validation as constructing
    /// one by hand — a corrupt or future-edited blob must throw, not play.
    func test_decode_invalidTarget_throws() {
        let rules = rules(target: 0)
        let data = try! JSONEncoder().encode(rules)
        XCTAssertThrowsError(try JSONDecoder().decode(PingPongRuleset.self, from: data))
    }

    func test_decode_invalidBestOf_throws() {
        let rules = rules(bestOf: 2)
        let data = try! JSONEncoder().encode(rules)
        XCTAssertThrowsError(try JSONDecoder().decode(PingPongRuleset.self, from: data))
    }

    func test_decode_missingWinByTwo_defaultsTrue() throws {
        var rules = rules(target: 11)
        rules.name = "Legacy no winByTwo"
        var data = try JSONEncoder().encode(rules)

        // Strip the winByTwo key from the encoded JSON and decode again — it
        // must fall back to true (playable), matching the pre-knob behavior.
        var obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        obj.removeValue(forKey: "winByTwo")
        data = try JSONSerialization.data(withJSONObject: obj)
        let decoded = try JSONDecoder().decode(PingPongRuleset.self, from: data)
        XCTAssertTrue(decoded.winByTwo)
        XCTAssertTrue(decoded.isValid)
    }

    // MARK: - Ping pong state init

    func test_state_init_setsInitialServers() {
        let state = PingPongState(initialServer: .b)
        XCTAssertEqual(state.initialServer, .b)
        XCTAssertEqual(state.gameInitialServer, .b)
        XCTAssertEqual(state.pointsA, 0)
        XCTAssertEqual(state.pointsB, 0)
        XCTAssertEqual(state.gamesWonA, 0)
        XCTAssertEqual(state.gamesWonB, 0)
    }

    // MARK: - Helpers

    private func rules(
        target: Int = 11,
        bestOf: Int = 5,
        serveMode: PingPongServeMode = .every2,
        winByTwo: Bool = true
    ) -> PingPongRuleset {
        PingPongRuleset(
            identifier: UUID(),
            name: "Test",
            pointsTarget: target,
            bestOf: bestOf,
            serveMode: serveMode,
            winByTwo: winByTwo
        )
    }
}