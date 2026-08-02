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
                if ruleset.sameKnobs(as: lib.draft, lib.sport) {
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
            // The open question of #141 rendered as the closed-ladder option:
            // four fixed rungs. Swap for a free list to feel the other answer.
            LabeledContent("Escalada") {
                HStack(spacing: 6) {
                    ForEach(Array(lib.draft.ladder.enumerated()), id: \.offset) { i, value in
                        Stepper("\(value)", value: Binding(
                            get: { lib.draft.ladder[i] },
                            set: { lib.draft.ladder[i] = $0 }
                        ), in: 1...24)
                        .labelsHidden()
                        .overlay(alignment: .leading) {
                            Text("\(value)").font(.caption.monospacedDigit()).offset(x: -14)
                        }
                    }
                }
            }
        }
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
        let selected = ruleset.sameKnobs(as: lib.draft, lib.sport)
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
                                .tint(ruleset.sameKnobs(as: lib.draft, lib.sport) ? .accentColor : .gray)
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
