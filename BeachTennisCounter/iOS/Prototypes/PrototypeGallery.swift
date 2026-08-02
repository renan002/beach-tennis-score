import SwiftUI

// PROTOTYPE — throwaway. Issue #126.
//
// Mounts the variants inside Dev Tools, which already exists and is already
// two taps deep behind Settings. Nothing new at top level, and nothing that can
// exist outside the Dev flavor.

#if DEV_FLAVOR

/// Question 1 — the Regras screen. Sport picker sits *above* the switcher: it is
/// context every variant shares, not part of what is being judged.
struct ProtoRegrasGallery: View {
    @State private var lib = ProtoLibrary()
    @State private var variant = 0

    private let names = ["Lista", "Galeria", "Frase"]

    var body: some View {
        VStack(spacing: 0) {
            Picker("Esporte", selection: Binding(
                get: { lib.sport },
                set: { lib.switchSport($0) }
            )) {
                ForEach(ProtoSport.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Group {
                switch variant {
                case 0: ProtoRegrasA(lib: lib)
                case 1: ProtoRegrasB(lib: lib)
                default: ProtoRegrasC(lib: lib)
                }
            }
            .overlay(alignment: .bottom) {
                ProtoSwitcher(names: names, index: $variant)
                    .padding(.bottom, 12)
            }
        }
        .navigationTitle("Regras")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Question 3 — the truco score screen on iPhone. The match state survives a
/// variant switch on purpose: the same six mãos should be legible in all three.
struct ProtoPlacarGallery: View {
    @State private var match = ProtoTrucoMatch()
    @State private var variant = 0

    private let names = ["Mesa", "Placar", "Caderno"]

    var body: some View {
        Group {
            switch variant {
            case 0: ProtoPlacarA(match: match)
            case 1: ProtoPlacarB(match: match)
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
                    ProtoRegrasGallery()
                } label: {
                    Label("Regras — 3 variants", systemImage: "slider.horizontal.3")
                }
                NavigationLink {
                    ProtoPlacarGallery()
                } label: {
                    Label("Placar de truco — 3 variants", systemImage: "suit.spade")
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
