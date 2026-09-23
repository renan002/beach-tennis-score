import Foundation

/// One sport's Ruleset library, as a single versioned JSON document stored in
/// `UserDefaults` (ADR 0006: libraries live outside SwiftData, away from the
/// Match History's migration path).
///
/// The document carries, per sport: the version, the saved custom Rulesets, and
/// the *active* Ruleset — its identity **and** its whole value in the same
/// document, so the watch always receives the value in effect rather than a
/// name the watch would have to re-resolve.
struct RulesetDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int
    let sport: MatchType
    /// The player's saved Custom Rulesets, newest last. Presets are never
    /// stored here — the active value materializes them as needed.
    var customRulesets: [Ruleset]
    /// The value the sport is played under. `nil` means the sport's built-in
    /// preset, which is also the fallback for a first launch or a document that
    /// predates the field.
    var activeRuleset: Ruleset?
    /// Ping pong only: the unsaved working value behind the "Personalizado"
    /// picker entry. Persisted so a knob edit survives navigation and relaunch.
    /// Stable identity across edits — it is never silently merged into a saved
    /// custom; saving copies it under a **new** UUID.
    var pingDraft: PingPongRuleset?

    init(
        sport: MatchType,
        customRulesets: [Ruleset] = [],
        activeRuleset: Ruleset? = nil,
        pingDraft: PingPongRuleset? = nil
    ) {
        self.version = Self.currentVersion
        self.sport = sport
        self.customRulesets = customRulesets
        self.activeRuleset = activeRuleset
        self.pingDraft = pingDraft
    }
}

/// The phone-side Ruleset library: load/save one document per sport, resolve
/// the active value (preset fallback), and mutate the library/draft. Pure JSON
/// over `UserDefaults` — no SwiftData, per ADR 0006.
enum RulesetLibrary {
    /// Per-sport storage key.
    static func key(for sport: MatchType) -> String {
        "RulesetLibrary.\(sport.rawValue)"
    }

    /// Posted on the main queue every time a document is saved. The phone's
    /// session manager observes it and pushes the (now changed) settings to the
    /// watch immediately.
    static let didChangeNotification = Notification.Name("RulesetLibrary.didChange")

    /// Loads the document, or falls back to a fresh one when the stored blob is
    /// missing, belongs to another sport, or carries an unsupported version.
    @discardableResult
    static func document(
        for sport: MatchType,
        in defaults: UserDefaults = .standard
    ) -> RulesetDocument {
        guard let data = defaults.data(forKey: key(for: sport)),
              let doc = try? JSONDecoder().decode(RulesetDocument.self, from: data),
              doc.sport == sport,
              doc.version == RulesetDocument.currentVersion
        else { return RulesetDocument(sport: sport) }
        return doc
    }

    static func save(_ doc: RulesetDocument, in defaults: UserDefaults = .standard) {
        guard doc.version == RulesetDocument.currentVersion else { return }
        if let data = try? JSONEncoder().encode(doc) {
            defaults.set(data, forKey: key(for: doc.sport))
        }
        NotificationCenter.default.post(name: didChangeNotification, object: doc.sport)
    }

    /// The active Ruleset for `sport`: the document's active value when set,
    /// otherwise the sport's built-in preset.
    static func activeRuleset(
        for sport: MatchType,
        in defaults: UserDefaults = .standard
    ) -> Ruleset {
        document(for: sport, in: defaults).activeRuleset ?? Ruleset.preset(for: sport)
    }

    /// The saved Custom Rulesets for `sport`.
    static func customRulesets(
        for sport: MatchType,
        in defaults: UserDefaults = .standard
    ) -> [Ruleset] {
        document(for: sport, in: defaults).customRulesets
    }

    /// Replaces the active value.
    static func setActiveRuleset(
        _ ruleset: Ruleset,
        for sport: MatchType,
        in defaults: UserDefaults = .standard
    ) {
        var doc = document(for: sport, in: defaults)
        guard ruleset.sport == sport else { return }
        doc.activeRuleset = ruleset
        save(doc, in: defaults)
    }

    /// Upserts a Custom Ruleset, preserving its identity. Does not touch the
    /// active value.
    static func upsertCustom(
        _ ruleset: Ruleset,
        for sport: MatchType,
        in defaults: UserDefaults = .standard
    ) {
        guard ruleset.sport == sport else { return }
        var doc = document(for: sport, in: defaults)
        doc.customRulesets.removeAll { $0.identifier == ruleset.identifier }
        doc.customRulesets.append(ruleset)
        save(doc, in: defaults)
    }

    /// Deletes a Custom Ruleset by identity. Deleting the active value falls
    /// back to the sport's preset; an inactive delete leaves the active
    /// untouched. Returns the active value after the deletion.
    static func deleteCustom(
        id: UUID,
        for sport: MatchType,
        in defaults: UserDefaults = .standard
    ) -> Ruleset? {
        var doc = document(for: sport, in: defaults)
        doc.customRulesets.removeAll { $0.identifier == id }
        if doc.activeRuleset?.identifier == id {
            doc.activeRuleset = nil
            save(doc, in: defaults)
            return Ruleset.preset(for: sport)
        }
        save(doc, in: defaults)
        return doc.activeRuleset
    }

    /// A draft copy of `source` under its **own** identity — a new UUID and the
    /// name "Custom" — so editing never aliases a preset or a saved custom.
    static func freshDraft(from source: PingPongRuleset) -> PingPongRuleset {
        PingPongRuleset(
            identifier: UUID(),
            name: String(localized: "Custom"),
            pointsTarget: source.pointsTarget,
            bestOf: source.bestOf,
            serveMode: source.serveMode,
            winByTwo: source.winByTwo
        )
    }

    /// The ping pong draft: the persisted working value, or a fresh independent
    /// draft when none has been saved yet.
    static func pingDraft(
        in defaults: UserDefaults = .standard
    ) -> PingPongRuleset {
        let doc = document(for: .pingPong, in: defaults)
        if let draft = doc.pingDraft { return draft }
        return freshDraft(from: doc.activeRuleset?.pingPong ?? .oficial)
    }

    /// Writes the draft and makes it the active value in one document write.
    static func updatePingDraftAndActive(_ draft: PingPongRuleset, in defaults: UserDefaults = .standard) {
        var doc = document(for: .pingPong, in: defaults)
        doc.pingDraft = draft
        doc.activeRuleset = .pingPong(draft)
        save(doc, in: defaults)
    }

    /// Saves the draft as a new Custom Ruleset — always a **new** UUID, never
    /// the draft's — and makes it the active value in one document write. The
    /// draft keeps its own identity. Returns the saved ruleset, or `nil` when
    /// the name is blank after trimming.
    static func saveDraftAsCustom(
        draft: PingPongRuleset,
        name: String,
        defaults: UserDefaults = .standard
    ) -> Ruleset? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, draft.isValid else { return nil }
        let custom = PingPongRuleset(
            identifier: UUID(),
            name: trimmed,
            pointsTarget: draft.pointsTarget,
            bestOf: draft.bestOf,
            serveMode: draft.serveMode,
            winByTwo: draft.winByTwo
        )
        let rules = Ruleset.pingPong(custom)
        var doc = document(for: .pingPong, in: defaults)
        doc.customRulesets.removeAll { $0.identifier == custom.identifier }
        doc.customRulesets.append(rules)
        doc.activeRuleset = rules
        save(doc, in: defaults)
        return rules
    }

    /// Renames a saved Custom Ruleset, preserving its UUID. When the custom is
    /// active, the active value follows the rename. Returns the renamed
    /// ruleset, or `nil` when the name is blank or no such custom exists.
    static func renameCustom(
        id: UUID,
        to newName: String,
        for sport: MatchType,
        in defaults: UserDefaults = .standard
    ) -> Ruleset? {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var doc = document(for: sport, in: defaults)
        guard let index = doc.customRulesets.firstIndex(where: { $0.identifier == id }) else { return nil }
        let existing = doc.customRulesets[index]
        let renamed: Ruleset
        if var ping = existing.pingPong {
            guard ping.isValid else { return nil }
            ping.name = trimmed
            renamed = Ruleset.pingPong(ping)
        } else {
            renamed = Ruleset(
                identifier: existing.identifier,
                name: trimmed,
                sport: existing.sport,
                hasSets: existing.hasSets,
                gamesToWinMatch: existing.gamesToWinMatch,
                tiebreakAtGames: existing.tiebreakAtGames,
                tiebreakPointsToWin: existing.tiebreakPointsToWin,
                tiebreakWinByTwo: existing.tiebreakWinByTwo,
                setsToWinMatch: existing.setsToWinMatch
            )
        }
        doc.customRulesets[index] = renamed
        if doc.activeRuleset?.identifier == id {
            doc.activeRuleset = renamed
        }
        save(doc, in: defaults)
        return renamed
    }
}