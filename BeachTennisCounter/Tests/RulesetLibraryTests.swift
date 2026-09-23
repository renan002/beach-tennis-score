import XCTest
@testable import BeachTennisCounter

/// The ping pong Rules library at its seam: an isolated `UserDefaults` suite,
/// so tests never touch the app's real library and never depend on teardown
/// order across suites.
final class RulesetLibraryTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName = ""

    override func setUp() {
        super.setUp()
        suiteName = "RulesetLibraryTests.\(UUID().uuidString)"
        guard let created = UserDefaults(suiteName: suiteName) else {
            return XCTFail("could not create suite")
        }
        defaults = created
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeCustom(named name: String, target: Int = 15, tag: UUID = UUID()) -> Ruleset {
        Ruleset.pingPong(PingPongRuleset(
            identifier: tag,
            name: name,
            pointsTarget: target,
            bestOf: 3,
            serveMode: .every5
        ))
    }

    private func customIdentifiers(_ sport: MatchType = .pingPong) -> [UUID] {
        RulesetLibrary.customRulesets(for: sport, in: defaults).map(\.identifier)
    }

    // MARK: - Fresh launch

    func test_freshLibrary_activeIsOficial() {
        XCTAssertNil(RulesetLibrary.document(for: .pingPong, in: defaults).activeRuleset)
        XCTAssertEqual(RulesetLibrary.activeRuleset(for: .pingPong, in: defaults).identifier,
                       PingPongRuleset.oficial.identifier)
    }

    func test_freshLibrary_draftIsOficialValues_withOwnIdentity() {
        let draft = RulesetLibrary.pingDraft(in: defaults)
        XCTAssertEqual(draft.pointsTarget, 11)
        XCTAssertEqual(draft.bestOf, 5)
        XCTAssertEqual(draft.serveMode, .every2)
        XCTAssertEqual(draft.name, String(localized: "Custom"))
        XCTAssertEqual(RulesetLibrary.document(for: .pingPong, in: defaults).pingDraft, nil)
    }

    // MARK: - Duplicate identities

    func test_twoCustoms_withIdenticalValues_keepSeparateIdentities() {
        let first = makeCustom(named: "Alpha", target: 15)
        let second = makeCustom(named: "Beta", target: 15)
        XCTAssertNotEqual(first.identifier, second.identifier)
        RulesetLibrary.upsertCustom(first, for: .pingPong, in: defaults)
        RulesetLibrary.upsertCustom(second, for: .pingPong, in: defaults)
        let ids = customIdentifiers()
        XCTAssertEqual(Set(ids), [first.identifier, second.identifier])
        XCTAssertEqual(ids.count, 2)
    }

    func test_upsertSameUUID_replacesInPlace() {
        let a = makeCustom(named: "Before", tag: UUID())
        RulesetLibrary.upsertCustom(a, for: .pingPong, in: defaults)
        let b = makeCustom(named: "After", target: 21, tag: a.identifier)
        RulesetLibrary.upsertCustom(b, for: .pingPong, in: defaults)
        XCTAssertEqual(customIdentifiers(), [a.identifier])
        XCTAssertEqual(RulesetLibrary.customRulesets(for: .pingPong, in: defaults).first?.name, "After")
    }

    // MARK: - Preset -> draft edits preserve the preset

    func test_presetSource_draftEdit_preservesPresetCustoms() {
        RulesetLibrary.setActiveRuleset(.pingPong(.oficial), for: .pingPong, in: defaults)
        let draft = RulesetLibrary.freshDraft(from: .oficial)
        let edited = PingPongRuleset(
            identifier: draft.identifier,
            name: draft.name,
            pointsTarget: 15,
            bestOf: draft.bestOf,
            serveMode: draft.serveMode
        )
        RulesetLibrary.updatePingDraftAndActive(edited, in: defaults)

        // Custom list stays empty — the preset is untouched.
        XCTAssertTrue(customIdentifiers().isEmpty)
        // Oficial preset value is still Oficial.
        XCTAssertEqual(PingPongRuleset.oficial.pointsTarget, 11)
        XCTAssertEqual(PingPongRuleset.oficial.bestOf, 5)
        // Active is now the draft.
        XCTAssertEqual(RulesetLibrary.activeRuleset(for: .pingPong, in: defaults).identifier,
                       draft.identifier)
        XCTAssertEqual(RulesetLibrary.activeRuleset(for: .pingPong, in: defaults).pingPong?.pointsTarget, 15)
    }

    // MARK: - Saved custom -> draft edits preserve the custom

    func test_customSource_draftEdit_preservesSavedCustom() {
        let custom = makeCustom(named: "Minha", target: 15)
        RulesetLibrary.upsertCustom(custom, for: .pingPong, in: defaults)
        RulesetLibrary.setActiveRuleset(custom, for: .pingPong, in: defaults)

        let draft = RulesetLibrary.freshDraft(from: custom.pingPong!)
        let edited = PingPongRuleset(
            identifier: draft.identifier,
            name: draft.name,
            pointsTarget: 11,
            bestOf: 5,
            serveMode: .every2
        )
        RulesetLibrary.updatePingDraftAndActive(edited, in: defaults)

        // The saved custom keeps its identity and value.
        XCTAssertEqual(customIdentifiers(), [custom.identifier])
        let stored = RulesetLibrary.customRulesets(for: .pingPong, in: defaults).first!
        XCTAssertEqual(stored.name, "Minha")
        XCTAssertEqual(stored.pingPong?.pointsTarget, 15)
        XCTAssertNotEqual(stored.identifier, draft.identifier)
    }

    // MARK: - Atomic draft + active

    func test_updateDraftAndActive_savesDraftAndActiveInOneWrite() {
        let draft = PingPongRuleset(
            identifier: UUID(),
            name: String(localized: "Custom"),
            pointsTarget: 21,
            bestOf: 1,
            serveMode: .rally
        )
        RulesetLibrary.updatePingDraftAndActive(draft, in: defaults)

        let doc = RulesetLibrary.document(for: .pingPong, in: defaults)
        XCTAssertEqual(doc.pingDraft, draft)
        XCTAssertEqual(doc.activeRuleset?.pingPong?.pointsTarget, 21)
    }

    // MARK: - Draft survives relaunch; selection derives from active

    func test_draftRelaunch_activeStillDraft() {
        let first = RulesetLibrary.pingDraft(in: defaults)
        let edited = PingPongRuleset(
            identifier: first.identifier,
            name: first.name,
            pointsTarget: 11,
            bestOf: 1,
            serveMode: .rally
        )
        RulesetLibrary.updatePingDraftAndActive(edited, in: defaults)

        // "Relaunch" — a fresh defaults handle over the same suite.
        guard let defaults2 = UserDefaults(suiteName: suiteName) else {
            return XCTFail("could not create suite")
        }

        let draft = RulesetLibrary.pingDraft(in: defaults2)
        XCTAssertEqual(draft.identifier, edited.identifier)
        XCTAssertEqual(draft.pointsTarget, 11)
        XCTAssertEqual(RulesetLibrary.activeRuleset(for: .pingPong, in: defaults2).identifier,
                       edited.identifier)
    }

    func test_choosePresetWithExistingDraft_relaunchStillPreset() {
        // Player drafts something, then explicitly picks Oficial.
        let draft = RulesetLibrary.pingDraft(in: defaults)
        let edited = PingPongRuleset(
            identifier: draft.identifier,
            name: draft.name,
            pointsTarget: 11,
            bestOf: 1,
            serveMode: .rally
        )
        RulesetLibrary.updatePingDraftAndActive(edited, in: defaults)
        RulesetLibrary.setActiveRuleset(.pingPong(.oficial), for: .pingPong, in: defaults)

        guard let defaults2 = UserDefaults(suiteName: suiteName) else {
            return XCTFail("could not create suite")
        }

        // The active is the preset — the persisted draft is not selected.
        let active = RulesetLibrary.activeRuleset(for: .pingPong, in: defaults2)
        XCTAssertEqual(active.identifier, PingPongRuleset.oficial.identifier)
        // The draft survives as data, only not as the selection.
        XCTAssertEqual(RulesetLibrary.pingDraft(in: defaults2).pointsTarget, edited.pointsTarget)
    }

    // MARK: - Save as new custom

    func test_saveDraftAsCustom_newUUID_atomicActiveAndCustom() {
        let draft = RulesetLibrary.pingDraft(in: defaults)
        let edited = PingPongRuleset(
            identifier: draft.identifier,
            name: draft.name,
            pointsTarget: 21,
            bestOf: 3,
            serveMode: .every5
        )
        let saved = RulesetLibrary.saveDraftAsCustom(draft: edited, name: "  Duzão  ", defaults: defaults)!

        XCTAssertEqual(saved.name, "Duzão")
        XCTAssertNotEqual(saved.identifier, edited.identifier)
        XCTAssertEqual(customIdentifiers(), [saved.identifier])
        // Atomic: the saved custom is also the active value.
        XCTAssertEqual(RulesetLibrary.activeRuleset(for: .pingPong, in: defaults).identifier,
                       saved.identifier)
    }

    func test_saveDraftAsCustom_blankName_returnsNilAndChangesNothing() {
        let before = customIdentifiers()
        let draft = RulesetLibrary.pingDraft(in: defaults)
        let saved = RulesetLibrary.saveDraftAsCustom(draft: draft, name: "   ", defaults: defaults)
        XCTAssertNil(saved)
        XCTAssertEqual(customIdentifiers(), before)
        XCTAssertEqual(RulesetLibrary.activeRuleset(for: .pingPong, in: defaults).identifier,
                       PingPongRuleset.oficial.identifier)
    }

    func test_saveDraftAsCustom_saveAgain_sameDraftDifferentUUID() {
        let draft = RulesetLibrary.pingDraft(in: defaults)
        let edited = PingPongRuleset(
            identifier: draft.identifier,
            name: draft.name,
            pointsTarget: 21,
            bestOf: 3,
            serveMode: .every5
        )
        let first = RulesetLibrary.saveDraftAsCustom(draft: edited, name: "First", defaults: defaults)!
        let second = RulesetLibrary.saveDraftAsCustom(draft: edited, name: "Second", defaults: defaults)!
        XCTAssertNotEqual(first.identifier, second.identifier)
        XCTAssertEqual(Set(customIdentifiers()), [first.identifier, second.identifier])
    }

    // MARK: - Rename

    func test_renameCustom_active_preservesUUID_updatesActiveAndList() {
        let custom = makeCustom(named: "Velho", target: 15)
        RulesetLibrary.upsertCustom(custom, for: .pingPong, in: defaults)
        RulesetLibrary.setActiveRuleset(custom, for: .pingPong, in: defaults)

        let renamed = RulesetLibrary.renameCustom(id: custom.identifier, to: "  Novo  ", for: .pingPong, in: defaults)!
        XCTAssertEqual(renamed.identifier, custom.identifier)
        XCTAssertEqual(renamed.name, "Novo")
        XCTAssertEqual(RulesetLibrary.activeRuleset(for: .pingPong, in: defaults).identifier,
                       custom.identifier)
        XCTAssertEqual(RulesetLibrary.activeRuleset(for: .pingPong, in: defaults).name, "Novo")
        let stored = RulesetLibrary.customRulesets(for: .pingPong, in: defaults).first!
        XCTAssertEqual(stored.identifier, custom.identifier)
        XCTAssertEqual(stored.name, "Novo")
        XCTAssertEqual(stored.pingPong?.identifier, custom.pingPong?.identifier)
    }

    func test_renameCustom_idle_leavesActiveUntouched() {
        let custom = makeCustom(named: "Idle")
        RulesetLibrary.upsertCustom(custom, for: .pingPong, in: defaults)
        // Active stays Oficial.

        let renamed = RulesetLibrary.renameCustom(id: custom.identifier, to: "Renomeada", for: .pingPong, in: defaults)!
        XCTAssertEqual(renamed.name, "Renomeada")
        XCTAssertEqual(RulesetLibrary.activeRuleset(for: .pingPong, in: defaults).identifier,
                       PingPongRuleset.oficial.identifier)
    }

    func test_renameCustom_blankName_returnsNil() {
        let custom = makeCustom(named: "Nome")
        RulesetLibrary.upsertCustom(custom, for: .pingPong, in: defaults)
        XCTAssertNil(RulesetLibrary.renameCustom(id: custom.identifier, to: "  ", for: .pingPong, in: defaults))
        XCTAssertEqual(RulesetLibrary.customRulesets(for: .pingPong, in: defaults).first?.name, "Nome")
    }

    func test_renameCustom_unknownID_returnsNil() {
        XCTAssertNil(RulesetLibrary.renameCustom(id: UUID(), to: "X", for: .pingPong, in: defaults))
    }

    // MARK: - Delete

    func test_deleteActiveCustom_fallsBackToOficial() {
        let custom = makeCustom(named: "Ativa")
        RulesetLibrary.upsertCustom(custom, for: .pingPong, in: defaults)
        RulesetLibrary.setActiveRuleset(custom, for: .pingPong, in: defaults)

        let activeAfter = RulesetLibrary.deleteCustom(id: custom.identifier, for: .pingPong, in: defaults)
        XCTAssertEqual(activeAfter?.identifier, PingPongRuleset.oficial.identifier)
        XCTAssertTrue(customIdentifiers().isEmpty)
        XCTAssertEqual(RulesetLibrary.activeRuleset(for: .pingPong, in: defaults).identifier,
                       PingPongRuleset.oficial.identifier)
    }

    func test_deleteInactiveCustom_leavesActiveUntouched() {
        let inactive = makeCustom(named: "Inativa", target: 15)
        RulesetLibrary.upsertCustom(inactive, for: .pingPong, in: defaults)
        RulesetLibrary.setActiveRuleset(.pingPong(.oficial), for: .pingPong, in: defaults)

        let activeAfter = RulesetLibrary.deleteCustom(id: inactive.identifier, for: .pingPong, in: defaults)
        XCTAssertEqual(activeAfter?.identifier, PingPongRuleset.oficial.identifier)
        XCTAssertTrue(customIdentifiers().isEmpty)
        XCTAssertEqual(RulesetLibrary.activeRuleset(for: .pingPong, in: defaults).identifier,
                       PingPongRuleset.oficial.identifier)
    }

    func test_deleteWithSavedDraft_stillActiveDraft_afterDelete() {
        let draft = RulesetLibrary.pingDraft(in: defaults)
        let edited = PingPongRuleset(
            identifier: draft.identifier,
            name: draft.name,
            pointsTarget: 21,
            bestOf: 3,
            serveMode: .rally
        )
        RulesetLibrary.updatePingDraftAndActive(edited, in: defaults)

        let activeAfter = RulesetLibrary.deleteCustom(id: UUID(), for: .pingPong, in: defaults)
        XCTAssertEqual(activeAfter?.identifier, edited.identifier)
        XCTAssertEqual(RulesetLibrary.pingDraft(in: defaults).identifier, edited.identifier)
    }

    // MARK: - Sports isolation

    func test_beachTennis_library_isIndependentOfPing() {
        RulesetLibrary.updatePingDraftAndActive(
            PingPongRuleset(identifier: UUID(), name: "X", pointsTarget: 15, bestOf: 1, serveMode: .rally),
            in: defaults
        )
        RulesetLibrary.upsertCustom(makeCustom(named: "Ping"), for: .pingPong, in: defaults)

        let beach = RulesetLibrary.document(for: .beachTennis, in: defaults)
        XCTAssertNil(beach.activeRuleset)
        XCTAssertTrue(beach.customRulesets.isEmpty)
        XCTAssertEqual(RulesetLibrary.activeRuleset(for: .beachTennis, in: defaults).identifier,
                       Ruleset.preset(for: .beachTennis).identifier)
    }
}