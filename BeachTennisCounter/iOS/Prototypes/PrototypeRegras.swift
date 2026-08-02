import SwiftUI

// PROTOTYPE — throwaway. Issue #126, question 1: "Regras cabe numa tela?"
//
// Three structurally different answers. They disagree about where the knobs
// live, not about colours:
//   A — Lista: presets, salvos and knobs all on one scrolling Form.
//   B — Galeria: cards on top, read-only summary below, knobs in a sheet.
//   C — Frase: the Ruleset is one editable sentence; every knob is an inline menu.

#if DEV_FLAVOR

// MARK: - A — Lista

/// Everything on one screen, Settings-shaped. Selecting a row applies it;
/// touching a knob demotes the selection to Personalizado in place.
struct ProtoRegrasA: View {
    @Bindable var lib: ProtoLibrary
    @State private var saveName = ""
    @State private var showSave = false

    var body: some View {
        Form {
            Section("Presets") {
                ForEach(lib.presets) { preset in
                    row(preset)
                }
            }

            if !lib.saved.isEmpty {
                Section("Minhas regras") {
                    ForEach(lib.saved) { custom in
                        row(custom)
                    }
                    .onDelete { lib.saved.remove(atOffsets: $0) }
                }
            }

            Section {
                ProtoKnobs(lib: lib)
            } header: {
                Text("Ajustes")
            } footer: {
                Text(lib.isDirty
                     ? "Regras alteradas. Salve para reutilizar."
                     : "Usando \(lib.draftLabel).")
            }

            if lib.isDirty {
                Section {
                    Button("Salvar como…") { showSave = true }
                }
            }
        }
        .alert("Nome das regras", isPresented: $showSave) {
            TextField("Truco do Zé", text: $saveName)
            Button("Salvar") { lib.save(as: saveName.isEmpty ? "Sem nome" : saveName); saveName = "" }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func row(_ ruleset: ProtoRuleset) -> some View {
        Button {
            lib.apply(ruleset)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ruleset.name)
                    Text(ruleset.summary(lib.sport))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if lib.applied?.id == ruleset.id {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

/// The knobs, shared by A and B's sheet. Two sports, three knobs each.
struct ProtoKnobs: View {
    @Bindable var lib: ProtoLibrary

    var body: some View {
        switch lib.sport {
        case .pingPong:
            Picker("Pontos por set", selection: $lib.draft.pointsPerSet) {
                Text("11").tag(11)
                Text("21").tag(21)
            }
            Picker("Melhor de", selection: $lib.draft.bestOf) {
                ForEach([1, 3, 5, 7], id: \.self) { Text("\($0)").tag($0) }
            }
            Picker("Saque", selection: $lib.draft.serve) {
                ForEach(ProtoServe.allCases) { Text($0.rawValue).tag($0) }
            }
        case .truco:
            Picker("Pontos para vencer", selection: $lib.draft.target) {
                Text("12").tag(12)
                Text("24").tag(24)
            }
            Picker("Valor da mão", selection: $lib.draft.base) {
                Text("1").tag(1)
                Text("2").tag(2)
            }
            // #141, both answers side by side. The **closed** ladder is one
            // `.menu` row like every other knob. The **free** list cannot be a
            // row at all — n Steppers do not fit on one line — so it is a
            // second screen. That cost is the finding, not a layout accident.
            Picker("Escalada", selection: ladder) {
                ForEach(ProtoRuleset.knownLadders, id: \.self) { rungs in
                    Text(rungs.map(String.init).joined(separator: " · ")).tag(rungs)
                }
                if !ProtoRuleset.knownLadders.contains(lib.draft.ladder) {
                    Text(lib.draft.ladder.map(String.init).joined(separator: " · "))
                        .tag(lib.draft.ladder)
                }
            }
            .pickerStyle(.menu)

            NavigationLink {
                ProtoLadderEditor(lib: lib)
            } label: {
                Text("Escalada personalizada")
            }
        }
    }

    private var ladder: Binding<[Int]> {
        Binding(get: { lib.draft.ladder }, set: { lib.draft.ladder = $0 })
    }
}

/// The free-list answer to #141: rungs are rows, so there can be any number of
/// them and each gets a full-width Stepper. Reachable only from Ajustes —
/// which is the point. A free list costs a screen.
struct ProtoLadderEditor: View {
    @Bindable var lib: ProtoLibrary

    var body: some View {
        List {
            Section {
                ForEach(Array(lib.draft.ladder.enumerated()), id: \.offset) { index, value in
                    Stepper(value: Binding(
                        get: { lib.draft.ladder.indices.contains(index) ? lib.draft.ladder[index] : value },
                        set: { if lib.draft.ladder.indices.contains(index) { lib.draft.ladder[index] = $0 } }
                    ), in: 1...24) {
                        HStack {
                            Text("Degrau \(index + 1)")
                            Spacer()
                            Text("\(value)")
                                .font(.body.monospacedDigit().weight(.semibold))
                        }
                    }
                }
                .onDelete { lib.draft.ladder.remove(atOffsets: $0) }

                Button("Adicionar degrau") {
                    lib.draft.ladder.append((lib.draft.ladder.last ?? 1) + 1)
                }
                .disabled(lib.draft.ladder.count >= 8)
            } footer: {
                Text("Cada degrau é quanto a mão passa a valer depois de mais um truco. Deslize para apagar.")
            }
        }
        .navigationTitle("Escalada")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - D — Menu

/// A's Ajustes section kept intact, with the preset *list* collapsed into one
/// `.menu` Picker — the same shape `Modalidade` already has on the Settings
/// screen. Costs one row instead of six, and the picker's own checkmark
/// replaces the hand-rolled one.
///
/// The trade the list was paying for: you no longer read every Ruleset's
/// summary at a glance. The footer buys part of it back by spelling out the
/// selected one.
struct ProtoRegrasD: View {
    @Bindable var lib: ProtoLibrary
    @State private var saveName = ""
    @State private var showSave = false
    @State private var renaming: ProtoRuleset?

    var body: some View {
        Form {
            Section {
                Picker("Regras", selection: selection) {
                    // Sections inside a .menu Picker keep Presets and saved
                    // Rulesets apart without costing a row on the screen.
                    Section("Presets") {
                        ForEach(lib.presets) { Text($0.name).tag(Optional($0.id)) }
                    }
                    if !lib.saved.isEmpty {
                        Section("Minhas regras") {
                            ForEach(lib.saved) { Text($0.name).tag(Optional($0.id)) }
                        }
                    }
                    if lib.isDirty {
                        // Only offered while it is true — a "Personalizado" you
                        // can *choose* would mean nothing.
                        Text("Personalizado").tag(UUID?.none)
                    }
                }
                .pickerStyle(.menu)
            } footer: {
                // No section header: it would repeat the row's own label, the
                // way "Sport / Modality" does not.
                Text(lib.draft.summary(lib.sport))
            }

            Section("Ajustes") {
                ProtoKnobs(lib: lib)
            }

            Section {
                if lib.isDirty {
                    Button("Salvar como…") { showSave = true }
                }
                if let applied = lib.applied, !applied.isPreset {
                    Button("Renomear") { renaming = applied; saveName = applied.name }
                    Button("Apagar", role: .destructive) {
                        lib.delete(applied)
                        lib.apply(lib.presets[0])
                    }
                }
            } footer: {
                Text(lib.isDirty
                     ? "Regras alteradas a partir de um preset."
                     : "Mudar qualquer ajuste vira Personalizado.")
            }
        }
        .alert("Nome das regras", isPresented: $showSave) {
            TextField("Truco do Zé", text: $saveName)
            Button("Salvar") { lib.save(as: saveName.isEmpty ? "Sem nome" : saveName); saveName = "" }
            Button("Cancelar", role: .cancel) {}
        }
        .alert("Renomear", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Nome", text: $saveName)
            Button("Salvar") {
                if let target = renaming, let i = lib.saved.firstIndex(where: { $0.id == target.id }) {
                    lib.saved[i].name = saveName.isEmpty ? "Sem nome" : saveName
                }
                renaming = nil
            }
            Button("Cancelar", role: .cancel) { renaming = nil }
        }
    }

    /// Nil is Personalizado, and selecting it is a no-op: the draft already is
    /// whatever the knobs say.
    private var selection: Binding<UUID?> {
        Binding(
            get: { lib.applied?.id },
            set: { newValue in
                guard let id = newValue, let ruleset = lib.all.first(where: { $0.id == id }) else { return }
                lib.apply(ruleset)
            }
        )
    }
}

// MARK: - B — Galeria

/// A calm read-only screen: pick a card, read the sentence. Editing is a
/// deliberate second step behind a sheet, so the dense part never greets you.
struct ProtoRegrasB: View {
    @Bindable var lib: ProtoLibrary
    @State private var showEditor = false
    @State private var saveName = ""
    @State private var showSave = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(lib.presets + lib.saved) { ruleset in
                            card(ruleset)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text(lib.draftLabel)
                        .font(.largeTitle.weight(.semibold))
                    Text(lib.draft.summary(lib.sport))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                VStack(spacing: 10) {
                    Button {
                        showEditor = true
                    } label: {
                        Label("Ajustar regras", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if lib.isDirty {
                        Button("Salvar estas regras") { showSave = true }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 80)
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                Form { ProtoKnobs(lib: lib) }
                    .navigationTitle("Ajustar")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Pronto") { showEditor = false }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        .alert("Nome das regras", isPresented: $showSave) {
            TextField("Truco do Zé", text: $saveName)
            Button("Salvar") { lib.save(as: saveName.isEmpty ? "Sem nome" : saveName); saveName = "" }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func card(_ ruleset: ProtoRuleset) -> some View {
        let selected = lib.applied?.id == ruleset.id
        return Button {
            lib.apply(ruleset)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(ruleset.name)
                    .font(.headline)
                Text(ruleset.summary(lib.sport))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if !ruleset.isPreset {
                    Text("MINHA").font(.caption2.weight(.bold)).foregroundStyle(.tint)
                }
            }
            .frame(width: 150, height: 110, alignment: .topLeading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selected ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.quaternary))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
            )
        }
        .foregroundStyle(.primary)
        .contextMenu {
            if !ruleset.isPreset {
                Button("Apagar", role: .destructive) { lib.delete(ruleset) }
            }
        }
    }
}

// MARK: - C — Frase

/// The Ruleset written the way it is said at the table, with each number a
/// tappable menu. No Form, no rows — the knobs *are* the summary.
struct ProtoRegrasC: View {
    @Bindable var lib: ProtoLibrary
    @State private var saveName = ""
    @State private var showSave = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(lib.presets + lib.saved) { ruleset in
                            Button(ruleset.name) { lib.apply(ruleset) }
                                .buttonStyle(.bordered)
                                .tint(lib.applied?.id == ruleset.id ? .accentColor : .gray)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 12)

                sentence
                    .font(.system(size: 30, weight: .light))
                    .lineSpacing(10)
                    .padding(.horizontal)

                if lib.isDirty {
                    Button("Salvar como…") { showSave = true }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                }

                Spacer(minLength: 80)
            }
        }
        .alert("Nome das regras", isPresented: $showSave) {
            TextField("Truco do Zé", text: $saveName)
            Button("Salvar") { lib.save(as: saveName.isEmpty ? "Sem nome" : saveName); saveName = "" }
            Button("Cancelar", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var sentence: some View {
        switch lib.sport {
        case .pingPong:
            VStack(alignment: .leading, spacing: 4) {
                inline("Sets de ", chip("\(lib.draft.pointsPerSet)") {
                    ForEach([11, 21], id: \.self) { v in
                        Button("\(v) pontos") { lib.draft.pointsPerSet = v }
                    }
                }, " pontos,")
                inline("melhor de ", chip("\(lib.draft.bestOf)") {
                    ForEach([1, 3, 5, 7], id: \.self) { v in
                        Button("\(v)") { lib.draft.bestOf = v }
                    }
                }, ",")
                inline("saque ", chip(lib.draft.serve.rawValue.lowercased()) {
                    ForEach(ProtoServe.allCases) { s in
                        Button(s.rawValue) { lib.draft.serve = s }
                    }
                }, ".")
            }
        case .truco:
            VStack(alignment: .leading, spacing: 4) {
                inline("Jogo até ", chip("\(lib.draft.target)") {
                    ForEach([12, 24], id: \.self) { v in
                        Button("\(v)") { lib.draft.target = v }
                    }
                }, " pontos,")
                inline("mão vale ", chip("\(lib.draft.base)") {
                    ForEach([1, 2], id: \.self) { v in
                        Button("\(v)") { lib.draft.base = v }
                    }
                }, ",")
                inline("truco sobe ", chip(lib.draft.ladder.map(String.init).joined(separator: "·")) {
                    Button("3 · 6 · 9 · 12") { lib.draft.ladder = [3, 6, 9, 12] }
                    Button("4 · 6 · 10 · 12") { lib.draft.ladder = [4, 6, 10, 12] }
                    Button("2 · 3 · 4") { lib.draft.ladder = [2, 3, 4] }
                }, ".")
            }
        }
    }

    private func inline(_ lead: String, _ middle: some View, _ tail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(lead)
            middle
            Text(tail)
        }
    }

    private func chip(_ label: String, @ViewBuilder menu: () -> some View) -> some View {
        Menu {
            menu()
        } label: {
            Text(label)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 8).fill(.tint.opacity(0.18)))
        }
    }
}

#endif
