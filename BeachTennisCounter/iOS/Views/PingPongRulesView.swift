import SwiftUI

/// Ping pong's Rules editor (iPhone).
///
/// The picker is grouped — the three presets, the player's saved custom rules,
/// then *Custom*, the unsaved working draft with a stable identity of its own.
/// Editing a knob never rewrites a preset or a saved custom: the edit lands on
/// the draft (a fresh independent draft when starting from a preset or custom)
/// and the draft becomes active in the same document write. "Save as new"
/// copies the draft under a **new** UUID into My rules and makes that the
/// active value; the draft keeps its own identity.
struct PingPongRulesView: View {
    enum Selection: Hashable {
        case preset(UUID)
        case custom(UUID)
        case draft
    }

    enum PointsMode: Hashable {
        case fixed(Int)
        case custom
    }

    @State private var selection: Selection = .draft
    /// The value the knobs edit. For a preset/custom selection it mirrors that
    /// value; a knob edit first moves it onto the independent draft.
    @State private var working: PingPongRuleset = .oficial
    @State private var customList: [Ruleset] = []
    @State private var pointsMode: PointsMode = .fixed(11)
    @State private var freeTargetText = "11"
    @State private var targetError: String?
    @State private var showSave = false
    @State private var showDelete = false
    @State private var showRename = false
    @State private var saveName = ""
    @State private var renameName = ""
    @State private var pendingDeleteName = ""

    var body: some View {
        List {
            Section {
                Picker("Rule set", selection: pickerSelection) {
                    Section("Presets") {
                        ForEach(PingPongRuleset.presets) { preset in
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
                    Button("Delete", role: .destructive) {
                        pendingDeleteName = working.name
                        showDelete = true
                    }
                }
            }

            Section {
                pointsRow
                bestOfRow
                serveRow
            } header: {
                Text("Knobs")
            }

            Section {
                summaryFooter
            } footer: {
                if let targetError {
                    Text(targetError)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Ping pong Rules")
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
                let trimmed = saveName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { saveAsNew(name: trimmed) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename rules", isPresented: $showRename) {
            TextField("Name", text: $renameName)
            Button("Save") {
                let trimmed = renameName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, case .custom(let id) = selection,
                   RulesetLibrary.renameCustom(id: id, to: trimmed, for: .pingPong) != nil {
                    loadFromLibrary()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete this rules?",
            isPresented: $showDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteSelected() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(pendingDeleteName)
        }
    }

    // MARK: - Library load

    /// Rebuilds picker, knobs and selection from the library. The selection is
    /// derived from the *active* identity — a persisted draft that is not the
    /// active value never selects itself.
    private func loadFromLibrary() {
        customList = RulesetLibrary.customRulesets(for: .pingPong)
        let doc = RulesetLibrary.document(for: .pingPong)
        guard let ping = RulesetLibrary.activeRuleset(for: .pingPong).pingPong else {
            selection = .draft
            working = doc.pingDraft ?? .oficial
            refreshDerived()
            return
        }
        working = ping
        if PingPongRuleset.presets.contains(where: { $0.identifier == ping.identifier }) {
            selection = .preset(ping.identifier)
        } else if customList.contains(where: { $0.identifier == ping.identifier }) {
            selection = .custom(ping.identifier)
        } else {
            selection = .draft
        }
        refreshDerived()
    }

    // MARK: - Selection

    /// Explicit selection writes — the picker never observes its own changes,
    /// so a load or a delete cannot re-trigger a selection while mutating.
    private var pickerSelection: Binding<Selection> {
        Binding(
            get: { selection },
            set: { newValue in
                guard newValue != selection else { return }
                choose(newValue)
            }
        )
    }

    private func choose(_ newSelection: Selection) {
        switch newSelection {
        case .preset(let id):
            guard let preset = PingPongRuleset.presets.first(where: { $0.identifier == id }) else { return }
            working = preset
            RulesetLibrary.setActiveRuleset(.pingPong(preset), for: .pingPong)
        case .custom(let id):
            guard let custom = customList.first(where: { $0.identifier == id })?.pingPong else { return }
            working = custom
            RulesetLibrary.setActiveRuleset(.pingPong(custom), for: .pingPong)
        case .draft:
            let draft = RulesetLibrary.pingDraft()
            working = draft
            RulesetLibrary.updatePingDraftAndActive(draft)
        }
        selection = newSelection
        targetError = nil
        refreshDerived()
    }

    // MARK: - Knobs

    private var pointsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Points per set", selection: pointsSelection) {
                ForEach([11, 21], id: \.self) { n in
                    Text("\(n)").tag(PointsMode.fixed(n))
                }
                Text("Custom").tag(PointsMode.custom)
            }
            .pickerStyle(.segmented)

            if pointsMode == .custom {
                TextField("Points", text: $freeTargetText)
                    .keyboardType(.numberPad)
                    .onChange(of: freeTargetText) {
                        applyFreeTarget()
                    }
            }
        }
    }

    /// Tapping *Custom* must reveal the free field even when the current target
    /// is a fixed 11 or 21, so the segment is its own mode rather than a
    /// mirror of `working.pointsTarget`.
    private var pointsSelection: Binding<PointsMode> {
        Binding(
            get: { pointsMode },
            set: { mode in
                targetError = nil
                switch mode {
                case .fixed(let target):
                    pointsMode = .fixed(target)
                    apply { $0.with(pointsTarget: target) }
                case .custom:
                    // Stay on the current value until the player types; the
                    // field is seeded so a fixed target is a one-key edit.
                    pointsMode = .custom
                    freeTargetText = "\(working.pointsTarget)"
                }
            }
        )
    }

    private func applyFreeTarget() {
        guard let value = Int(freeTargetText), value > 0 else {
            targetError = String(localized: "Enter a positive number of points.")
            return
        }
        targetError = nil
        guard value != working.pointsTarget else { return }
        apply { $0.with(pointsTarget: value) }
    }

    private var bestOfRow: some View {
        Picker("Best of", selection: bestOfSelection) {
            ForEach(PingPongRuleset.validBestOf, id: \.self) { n in
                Text("\(n)").tag(n)
            }
        }
    }

    private var bestOfSelection: Binding<Int> {
        Binding(
            get: { working.bestOf },
            set: { value in apply { $0.with(bestOf: value) } }
        )
    }

    private var serveRow: some View {
        Picker("Serve", selection: serveSelection) {
            ForEach(PingPongServeMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
    }

    private var serveSelection: Binding<PingPongServeMode> {
        Binding(
            get: { working.serveMode },
            set: { mode in apply { $0.with(serveMode: mode) } }
        )
    }

    /// Turns a knob edit into a draft write. From a preset or custom selection
    /// the edit starts on a fresh independent draft; from the draft it keeps
    /// the draft's stable identity. Draft and active update in one write.
    private func apply(_ transform: (PingPongRuleset) -> PingPongRuleset) {
        let base: PingPongRuleset
        switch selection {
        case .draft: base = working
        case .preset, .custom: base = RulesetLibrary.freshDraft(from: working)
        }
        let next = transform(base)
        guard next.isValid else { return }
        working = next
        RulesetLibrary.updatePingDraftAndActive(next)
        selection = .draft
        targetError = nil
        refreshDerived()
    }

    // MARK: - Derived

    private func refreshDerived() {
        freeTargetText = "\(working.pointsTarget)"
        pointsMode = (working.pointsTarget == 11 || working.pointsTarget == 21)
            ? .fixed(working.pointsTarget)
            : .custom
    }

    private var summaryFooter: some View {
        Text(String(localized: "\(working.pointsTarget) points per set · best of \(working.bestOf) · \(working.serveMode.displayName)"))
            .foregroundStyle(.secondary)
    }

    // MARK: - Save / Delete / Rename

    private func saveAsNew(name: String) {
        guard RulesetLibrary.saveDraftAsCustom(draft: working, name: name) != nil else { return }
        loadFromLibrary()
    }

    private func deleteSelected() {
        guard case .custom(let id) = selection else { return }
        RulesetLibrary.deleteCustom(id: id, for: .pingPong)
        loadFromLibrary()
    }
}

private extension PingPongRuleset {
    /// A copy with the given knobs replaced — `PingPongRuleset` fields are
    /// immutable (ADR 0006 stamping), so an edit builds a new value.
    func with(
        pointsTarget: Int? = nil,
        bestOf: Int? = nil,
        serveMode: PingPongServeMode? = nil
    ) -> PingPongRuleset {
        PingPongRuleset(
            identifier: identifier,
            name: name,
            pointsTarget: pointsTarget ?? self.pointsTarget,
            bestOf: bestOf ?? self.bestOf,
            serveMode: serveMode ?? self.serveMode,
            winByTwo: winByTwo
        )
    }
}