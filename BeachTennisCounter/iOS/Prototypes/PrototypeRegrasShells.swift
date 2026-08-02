import SwiftUI

// PROTOTYPE — throwaway. Issue #126, the sport axis.
//
// The first pass put the sport on a segmented Picker with two sports on it.
// #61 has four, and two of them — beach tennis and tennis — have **frozen**
// Rulesets: they belong on the screen but have nothing to edit. A segmented
// control handles neither the count nor that split.
//
// Three shells, same body (Variant D) inside each:
//   S1 — Abas: a TabView, one tab per sport.
//   S2 — Lista: Regras is a list of sports; each pushes its own screen.  ← ESCOLHIDA
//   S3 — Menu: one screen, sport chosen by a `.menu` row above the Ruleset row.
//
// **S2 + Variant D is the decided shape** for the Regras screen. S1 and S3
// stay here because this branch is the primary source for the decision — they
// do not come along when the real screen is written.

#if DEV_FLAVOR

// MARK: - S1 — Abas

/// One tab per sport. Reads well with four and dies at five (iOS folds the
/// rest into "More"), and every sport pays equal weight — including the two
/// that have nothing to change.
///
/// The real objection is structural: #61 already puts a TabView at the root
/// (Placar / Histórico / Estatísticas). This is a second tab bar inside the
/// third tab.
struct ProtoRegrasS1: View {
    @Bindable var store: ProtoRegrasStore
    @State private var sport: ProtoSport = .truco

    var body: some View {
        TabView(selection: $sport) {
            ForEach(ProtoSport.allCases) { each in
                Tab(each.rawValue, systemImage: each.icon, value: each) {
                    NavigationStack {
                        ProtoRegrasD(lib: store.library(each))
                            .navigationTitle(each.rawValue)
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
        }
    }
}

// MARK: - S2 — Lista

/// Regras is a list of sports, each row carrying the name of its active
/// Ruleset as its value — so the whole configuration is legible without
/// opening anything. Scales past four, and the frozen sports get to say so in
/// place instead of being a tab that disappoints.
struct ProtoRegrasS2: View {
    @Bindable var store: ProtoRegrasStore

    var body: some View {
        List {
            Section {
                ForEach(ProtoSport.editable) { sport in
                    NavigationLink {
                        ProtoRegrasD(lib: store.library(sport))
                            .navigationTitle(sport.rawValue)
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        row(sport)
                    }
                }
            } footer: {
                Text("As regras valem para partidas novas. Partidas já jogadas guardam as regras que estavam valendo.")
            }

            Section {
                ForEach(ProtoSport.allCases.filter { !$0.isEditable }) { sport in
                    row(sport)
                }
            } header: {
                Text("Regras fixas")
            } footer: {
                Text("Beach tennis e tennis seguem as regras oficiais e não são editáveis.")
            }
        }
    }

    private func row(_ sport: ProtoSport) -> some View {
        let lib = store.library(sport)
        return HStack {
            Label(sport.rawValue, systemImage: sport.icon)
            Spacer()
            Text(lib.draftLabel)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - S3 — Menu

/// Everything stays on one screen: a `.menu` row picks the sport, the body
/// below reconfigures. Cheapest of the three, and the only one where "which
/// sport am I editing" and "which Ruleset is active" sit in the same visual
/// slot — which is either tidy or confusing, and that is the thing to judge.
struct ProtoRegrasS3: View {
    @Bindable var store: ProtoRegrasStore
    @State private var sport: ProtoSport = .truco

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Esporte", selection: $sport) {
                        ForEach(ProtoSport.allCases) { each in
                            Label(each.rawValue, systemImage: each.icon).tag(each)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .frame(height: 92)
            .scrollDisabled(true)

            ProtoRegrasD(lib: store.library(sport))
        }
    }
}

#endif
