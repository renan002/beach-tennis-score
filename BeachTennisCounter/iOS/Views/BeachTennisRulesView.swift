import SwiftUI

/// Beach tennis's Rules editor (iPhone). Same shape as `TrucoRulesView`: one
/// menu of the Padrão preset, saved rules and the *Custom* draft; a knob edit
/// always lands on the draft. Knobs that cannot matter under the others are
/// hidden rather than shown inert (#205).
struct BeachTennisRulesView: View {
    enum Selection: Hashable {
        case preset(UUID)
        case custom(UUID)
        case draft
    }

    @State private var selection: Selection = .draft
    @State private var working: BeachTennisRuleset = .padrao
    @State private var customList: [Ruleset] = []
    @State private var showSave = false
    @State private var showDelete = false
    @State private var showRename = false
    @State private var saveName = ""
    @State private var renameName = ""

    var body: some View {
        List {
            Section {
                Picker("Rule set", selection: pickerSelection) {
                    Section("Presets") {
                        ForEach(BeachTennisRuleset.presets) { preset in
                            Text(preset.name).tag(Selection.preset(preset.identifier))
                        }
                    }
                    Section("My rules") {
                        ForEach(customList, id: \.identifier) { custom in
                            Text(custom.name).tag(Selection.custom(custom.identifier))
                        }
                    }
                    Section("Custom") {
                        Text("Custom").tag(Selection.draft)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Rules")
            }

            if case .custom = selection {
                Section {
                    Button("Rename") {
                        renameName = working.name
                        showRename = true
                    }
                    Button("Delete", role: .destructive) { showDelete = true }
                }
            }

            Section {
                Picker("Format", selection: binding(\.format) { $0.with(format: $1) }) {
                    ForEach(BeachMatchFormat.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Stepper(value: binding(\.sets) { $0.with(sets: $1) }, in: BeachTennisRuleset.validSets) {
                    LabeledContent("Sets", value: "\(working.sets)")
                }
                if working.format == .firstTo {
                    Toggle("Win by 2 sets", isOn: binding(\.winByTwoSets) { $0.with(winByTwoSets: $1) })
                    if working.winByTwoSets {
                        Toggle("Tiebreak", isOn: binding(\.tiebreak) { $0.with(tiebreak: $1) })
                    }
                }
                if working.tiebreakCanTrigger && working.tiebreak {
                    Stepper(
                        value: binding(\.tiebreakPoints) { $0.with(tiebreakPoints: $1) },
                        in: BeachTennisRuleset.validTiebreakPoints
                    ) {
                        LabeledContent("Tiebreak points", value: "\(working.tiebreakPoints)")
                    }
                    Toggle("Tiebreak: win by 2", isOn: binding(\.tiebreakWinByTwo) { $0.with(tiebreakWinByTwo: $1) })
                }
                Picker("At 40–40", selection: binding(\.deuceRule) { $0.with(deuceRule: $1) }) {
                    ForEach(BeachDeuceRule.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            } header: {
                Text("Knobs")
            }

            Section {
                Text(Self.summary(working)).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Beach Tennis Rules")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save as new") {
                    saveName = ""
                    showSave = true
                }
                .disabled(selection != .draft)
            }
        }
        .onAppear(perform: loadFromLibrary)
        .alert("Save as new rules", isPresented: $showSave) {
            TextField("Name", text: $saveName)
            Button("Save") {
                if RulesetLibrary.saveBeachDraftAsCustom(draft: working, name: saveName) != nil {
                    loadFromLibrary()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename rules", isPresented: $showRename) {
            TextField("Name", text: $renameName)
            Button("Save") {
                if case .custom(let id) = selection,
                   RulesetLibrary.renameCustom(id: id, to: renameName, for: .beachTennis) != nil {
                    loadFromLibrary()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this rules?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if case .custom(let id) = selection {
                    RulesetLibrary.deleteCustom(id: id, for: .beachTennis)
                    loadFromLibrary()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(working.name)
        }
    }

    // MARK: - Library

    /// Selection is derived from the *active* identity, as in ping pong.
    private func loadFromLibrary() {
        customList = RulesetLibrary.customRulesets(for: .beachTennis)
        let active = RulesetLibrary.activeRuleset(for: .beachTennis).beachRules
        working = active
        if active.isPreset {
            selection = .preset(active.identifier)
        } else if customList.contains(where: { $0.identifier == active.identifier }) {
            selection = .custom(active.identifier)
        } else {
            selection = .draft
        }
    }

    private var pickerSelection: Binding<Selection> {
        Binding(get: { selection }, set: { newValue in
            guard newValue != selection else { return }
            switch newValue {
            case .preset(let id):
                guard let preset = BeachTennisRuleset.presets.first(where: { $0.identifier == id }) else { return }
                working = preset
                RulesetLibrary.setActiveRuleset(.beachTennis(preset), for: .beachTennis)
            case .custom(let id):
                guard let custom = customList.first(where: { $0.identifier == id })?.beachTennis else { return }
                working = custom
                RulesetLibrary.setActiveRuleset(.beachTennis(custom), for: .beachTennis)
            case .draft:
                working = RulesetLibrary.beachDraft()
                RulesetLibrary.updateBeachDraftAndActive(working)
            }
            selection = newValue
        })
    }

    // MARK: - Knobs

    private func binding<T>(
        _ keyPath: KeyPath<BeachTennisRuleset, T>,
        _ set: @escaping (BeachTennisRuleset, T) -> BeachTennisRuleset
    ) -> Binding<T> {
        Binding(get: { working[keyPath: keyPath] }, set: { v in apply { set($0, v) } })
    }

    /// A knob edit lands on the draft — a fresh independent one when starting
    /// from a preset or a saved rule — and becomes active in the same write.
    /// Sempre N with an even N cannot end drawn, so its Tiebreak is forced on
    /// (the toggle is hidden there) instead of refusing the edit.
    private func apply(_ transform: (BeachTennisRuleset) -> BeachTennisRuleset) {
        let base = selection == .draft ? working : RulesetLibrary.freshDraft(from: working)
        var next = transform(base)
        if next.requiresTiebreak {
            next = next.with(tiebreak: true)
        }
        guard next.isValid else { return }
        working = next
        RulesetLibrary.updateBeachDraftAndActive(next)
        selection = .draft
    }

    // MARK: - Copy

    /// One line: "First to 6 · tiebreak to 7 · Golden point".
    static func summary(_ rules: BeachTennisRuleset) -> String {
        var parts = [
            rules.format == .firstTo
                ? String(localized: "First to \(rules.sets)")
                : String(localized: "Always \(rules.sets)")
        ]
        if rules.tiebreakCanTrigger && rules.tiebreak {
            parts.append(String(localized: "tiebreak to \(rules.tiebreakPoints)"))
        }
        parts.append(rules.deuceRule.displayName)
        return parts.joined(separator: " · ")
    }
}
