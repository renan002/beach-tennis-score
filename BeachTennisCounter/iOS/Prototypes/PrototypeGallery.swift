import SwiftUI

// PROTOTYPE — throwaway. Issue #126.
//
// Mounts the variants inside Dev Tools, which already exists and is already
// two taps deep behind Settings. Nothing new at top level, and nothing that can
// exist outside the Dev flavor.

#if DEV_FLAVOR

/// Question 1, sport axis — how the four sports of #61 hang off Regras. The
/// body is Variant D in all three, so only the shell is under judgement.
struct ProtoRegrasShellGallery: View {
    @State private var store = ProtoRegrasStore()
    @State private var variant = 0

    private let names = ["S2 — Lista", "S1 — Abas", "S3 — Menu"]

    var body: some View {
        Group {
            switch variant {
            case 0: ProtoRegrasS2(store: store)
            case 1: ProtoRegrasS1(store: store)
            default: ProtoRegrasS3(store: store)
            }
        }
        .overlay(alignment: .bottom) {
            ProtoSwitcher(names: names, index: $variant)
                .padding(.bottom, 12)
        }
        .navigationTitle("Regras")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Question 1, body axis — the density comparison from the first pass. Only the
/// two editable sports, because a frozen sport has no knobs to be dense about.
struct ProtoRegrasGallery: View {
    @State private var store = ProtoRegrasStore()
    @State private var sport: ProtoSport = .truco
    @State private var variant = 0

    // D first: it is the direction the review asked for, so it is what opens.
    private let names = ["D — Menu", "A — Lista", "B — Galeria", "C — Frase"]

    var body: some View {
        VStack(spacing: 0) {
            Picker("Esporte", selection: $sport) {
                ForEach(ProtoSport.editable) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Group {
                switch variant {
                case 0: ProtoRegrasD(lib: store.library(sport))
                case 1: ProtoRegrasA(lib: store.library(sport))
                case 2: ProtoRegrasB(lib: store.library(sport))
                default: ProtoRegrasC(lib: store.library(sport))
                }
            }
            .overlay(alignment: .bottom) {
                ProtoSwitcher(names: names, index: $variant)
                    .padding(.bottom, 12)
            }
        }
        .navigationTitle("Regras — corpo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Question 3 — the truco score screen on iPhone. The match state survives a
/// variant switch on purpose: the same six mãos should be legible in all three.
struct ProtoPlacarGallery: View {
    @State private var match = ProtoTrucoMatch()
    @State private var variant = 0

    // D first: it is the mix the review asked for, so it is what opens.
    private let names = ["D — Placar + caderno (escolhida)", "A — Mesa", "B — Placar", "C — Caderno"]

    var body: some View {
        Group {
            switch variant {
            case 0: ProtoPlacarD(match: match)
            case 1: ProtoPlacarA(match: match)
            case 2: ProtoPlacarB(match: match)
            default: ProtoPlacarC(match: match)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .bottom) {
            ProtoSwitcher(names: names, index: $variant)
                .padding(.bottom, 34)
        }
        .navigationTitle("Placar de truco")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let winner = match.winner {
                    Text("\(match.names[winner]) venceu")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
        }
    }
}

/// The Dev Tools entry. One row per question, so the two galleries are found
/// the same way the Seeder is.
struct PrototypesToolView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    ProtoRegrasShellGallery()
                } label: {
                    Label("Regras: esportes — S2 escolhida", systemImage: "square.grid.2x2")
                }
                NavigationLink {
                    ProtoRegrasGallery()
                } label: {
                    Label("Regras: corpo — D escolhida", systemImage: "slider.horizontal.3")
                }
                NavigationLink {
                    ProtoPlacarGallery()
                } label: {
                    Label("Placar de truco — D escolhida", systemImage: "suit.spade")
                }
            } header: {
                Text("Issue #126")
            } footer: {
                Text("Throwaway prototypes. The watch prototype (long press for Valor da mão) lives on the Beach Dev Watch scheme, under New Match.")
            }
        }
        .navigationTitle("Prototypes")
    }
}

#endif
