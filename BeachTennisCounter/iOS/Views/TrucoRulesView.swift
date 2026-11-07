import SwiftUI

/// Truco's Rules editor (iPhone). Same shape as `PingPongRulesView`: one menu
/// of presets, saved rules and the *Custom* draft; a knob edit always lands on
/// the draft (#126). The raise ladder is a menu of the known ladders plus
/// "Custom…", which pushes the free-list editor (#141).
struct TrucoRulesView: View {
    enum Selection: Hashable {
        case preset(UUID)
        case custom(UUID)
        case draft
    }

    /// The ladders players actually use, one per Preset.
    static let knownLadders: [[Int]] = TrucoRuleset.presets.map(\.raises)

    @State private var selection: Selection = .draft
    @State private var working: TrucoRuleset = .paulista
    @State private var customList: [Ruleset] = []
    @State private var editError: String?
    @State private var showLadderEditor = false
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
                        ForEach(TrucoRuleset.presets) { preset in
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
                Stepper(value: targetBinding, in: 1...99) {
                    LabeledContent("Points to win", value: "\(working.pointsTarget)")
                }
                Picker("Base value", selection: baseBinding) {
                    ForEach(TrucoRuleset.validBaseValues, id: \.self) { Text("\($0)").tag($0) }
                }
                Picker("Raises", selection: ladderBinding) {
                    ForEach(Self.knownLadders, id: \.self) { ladder in
                        Text(Self.ladderText(ladder)).tag(Optional(ladder))
                    }
                    if !Self.knownLadders.contains(working.raises) {
                        Text(Self.ladderText(working.raises)).tag(Optional(working.raises))
                    }
                    Text("Custom…").tag([Int]?.none)
                }
            } header: {
                Text("Knobs")
            } footer: {
                if let editError {
                    Text(editError).foregroundStyle(.red)
                }
            }

            Section {
                Text(Self.summary(working)).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Truco Rules")
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
        .navigationDestination(isPresented: $showLadderEditor) {
            TrucoLadderEditor(base: working.baseValue, initial: working.raises) { raises in
                apply { $0.with(raises: raises) }
            }
        }
        .onAppear(perform: loadFromLibrary)
        .alert("Save as new rules", isPresented: $showSave) {
            TextField("Name", text: $saveName)
            Button("Save") {
                if RulesetLibrary.saveTrucoDraftAsCustom(draft: working, name: saveName) != nil {
                    loadFromLibrary()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename rules", isPresented: $showRename) {
            TextField("Name", text: $renameName)
            Button("Save") {
                if case .custom(let id) = selection,
                   RulesetLibrary.renameCustom(id: id, to: renameName, for: .truco) != nil {
                    loadFromLibrary()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this rules?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if case .custom(let id) = selection {
                    RulesetLibrary.deleteCustom(id: id, for: .truco)
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
        customList = RulesetLibrary.customRulesets(for: .truco)
        let active = RulesetLibrary.activeRuleset(for: .truco).truco ?? .paulista
        working = active
        if active.isPreset {
            selection = .preset(active.identifier)
        } else if customList.contains(where: { $0.identifier == active.identifier }) {
            selection = .custom(active.identifier)
        } else {
            selection = .draft
        }
        editError = nil
    }

    private var pickerSelection: Binding<Selection> {
        Binding(get: { selection }, set: { newValue in
            guard newValue != selection else { return }
            switch newValue {
            case .preset(let id):
                guard let preset = TrucoRuleset.presets.first(where: { $0.identifier == id }) else { return }
                working = preset
                RulesetLibrary.setActiveRuleset(.truco(preset), for: .truco)
            case .custom(let id):
                guard let custom = customList.first(where: { $0.identifier == id })?.truco else { return }
                working = custom
                RulesetLibrary.setActiveRuleset(.truco(custom), for: .truco)
            case .draft:
                working = RulesetLibrary.trucoDraft()
                RulesetLibrary.updateTrucoDraftAndActive(working)
            }
            selection = newValue
            editError = nil
        })
    }

    // MARK: - Knobs

    private var targetBinding: Binding<Int> {
        Binding(get: { working.pointsTarget }, set: { v in apply { $0.with(pointsTarget: v) } })
    }

    private var baseBinding: Binding<Int> {
        Binding(get: { working.baseValue }, set: { v in apply { $0.with(baseValue: v) } })
    }

    /// `nil` is "Custom…": it opens the free-list editor instead of applying.
    private var ladderBinding: Binding<[Int]?> {
        Binding(get: { working.raises }, set: { ladder in
            if let ladder { apply { $0.with(raises: ladder) } } else { showLadderEditor = true }
        })
    }

    /// A knob edit lands on the draft — a fresh independent one when starting
    /// from a preset or a saved rule — and becomes active in the same write.
    private func apply(_ transform: (TrucoRuleset) -> TrucoRuleset) {
        let base = selection == .draft ? working : RulesetLibrary.freshDraft(from: working)
        let next = transform(base)
        guard next.isValid else {
            editError = String(localized: "Raises must go up, starting above the base value.")
            return
        }
        working = next
        RulesetLibrary.updateTrucoDraftAndActive(next)
        selection = .draft
        editError = nil
    }

    // MARK: - Copy

    static func ladderText(_ raises: [Int]) -> String {
        raises.map(String.init).joined(separator: " · ")
    }

    static func summary(_ rules: TrucoRuleset) -> String {
        String(localized: "\(rules.pointsTarget) points to win · hands of \(ladderText(rules.stakes))")
    }
}

/// The free-list ladder editor behind "Custom…": 1 to 4 raises, strictly
/// increasing from above the base (#141). Applies only a valid ladder.
private struct TrucoLadderEditor: View {
    let base: Int
    @State var raises: [Int]
    let onApply: ([Int]) -> Void
    @Environment(\.dismiss) private var dismiss

    init(base: Int, initial: [Int], onApply: @escaping ([Int]) -> Void) {
        self.base = base
        self._raises = State(initialValue: initial)
        self.onApply = onApply
    }

    private var isValid: Bool { TrucoRuleset.isValidLadder(raises, base: base) }

    var body: some View {
        List {
            Section {
                ForEach(raises.indices, id: \.self) { i in
                    Stepper(value: $raises[i], in: 1...99) {
                        LabeledContent(String(localized: "Raise \(i + 1)"), value: "\(raises[i])")
                    }
                }
                .onDelete { raises.remove(atOffsets: $0) }
                if raises.count < TrucoRuleset.maxRaises {
                    Button("Add raise") { raises.append((raises.last ?? base) + 1) }
                }
            } footer: {
                if !isValid {
                    Text("Raises must go up, starting above the base value.")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Raises")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    onApply(raises)
                    dismiss()
                }
                .disabled(!isValid)
            }
        }
    }
}
