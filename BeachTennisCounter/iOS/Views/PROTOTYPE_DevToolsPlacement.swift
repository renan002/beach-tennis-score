// PROTOTYPE — throwaway. Not production code. Delete before #148 lands.
//
// Question: where does the Dev Tools affordance live?
// Three variants of the Dev Tools placement, switchable from a floating bottom
// bar, mounted on the real Match List so they are judged against real chrome
// and real data:
//
//   A — Buried in Settings: a "Developer" section → pushed Dev Tools screen.
//   B — Floating bubble: a draggable bubble over any screen → expanding panel
//       laid out as a tool dock, so more tools can be added later.
//   C — Toolbar item: a hammer next to the gear on Match List → sheet.
//
// Every action here is a stub. The prototype answers "what should this look
// like", not "does the seeder work".

#if DEV

import SwiftUI

// MARK: - Variant switcher

enum PrototypeVariant: String, CaseIterable {
    case a = "A"
    case b = "B"
    case c = "C"

    var name: String {
        switch self {
        case .a: return "Buried in Settings"
        case .b: return "Floating bubble"
        case .c: return "Toolbar item"
        }
    }

    var next: PrototypeVariant {
        let all = PrototypeVariant.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    var previous: PrototypeVariant {
        let all = PrototypeVariant.allCases
        return all[(all.firstIndex(of: self)! + all.count - 1) % all.count]
    }
}

/// Reload-stable, and readable from both Match List and Settings — the
/// analogue of the `?variant=` search param the skill describes.
let prototypeVariantKey = "PROTOTYPE_devToolsVariant"

/// The floating bar. Deliberately high-contrast so it never reads as part of
/// the design being evaluated.
struct PrototypeSwitcherBar: View {
    @AppStorage(prototypeVariantKey) private var raw: String = PrototypeVariant.a.rawValue

    private var variant: PrototypeVariant {
        PrototypeVariant(rawValue: raw) ?? .a
    }

    var body: some View {
        HStack(spacing: 14) {
            Button { raw = variant.previous.rawValue } label: {
                Image(systemName: "chevron.left")
            }

            Text("\(variant.rawValue) — \(variant.name)")
                .font(.caption.weight(.semibold))
                .frame(minWidth: 150)

            Button { raw = variant.next.rawValue } label: {
                Image(systemName: "chevron.right")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.black.opacity(0.85)))
        .shadow(radius: 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Shared stub payload

/// The tools themselves are the same in every variant — the placement is what
/// varies. Sport / count / date range / strength / seed, per the settled
/// parameter set.
struct PrototypeSeederParameters {
    var sport: String = "beachTennis"
    var count: Int = 20
    var from: Date = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
    var to: Date = Date()
    var strength: Double = 0.55
    var seed: Int = 42
}

/// The parameter form as a `Form` section stack — used by variants A and C.
struct PrototypeSeederForm: View {
    @Binding var params: PrototypeSeederParameters
    @State private var confirmWipe = false

    var body: some View {
        Section("Population") {
            Picker("Sport", selection: $params.sport) {
                Text("Beach Tennis").tag("beachTennis")
                Text("Tennis").tag("tennis")
                Text("Mixed").tag("mixed")
            }
            Stepper("Matches: \(params.count)", value: $params.count, in: 1...200)
            DatePicker("From", selection: $params.from, displayedComponents: .date)
            DatePicker("To", selection: $params.to, displayedComponents: .date)
        }

        Section {
            VStack(alignment: .leading) {
                Text("Team A strength: \(Int(params.strength * 100))%")
                    .font(.subheadline)
                Slider(value: $params.strength, in: 0.35...0.65)
            }
            Stepper("Seed: \(params.seed)", value: $params.seed, in: 0...9999)
        } header: {
            Text("Shape")
        } footer: {
            Text("Point-win probability for Team A. The same seed and parameters produce the same matches.")
        }

        Section {
            Button("Seed \(params.count) matches") {}
            Button("Wipe Match History", role: .destructive) { confirmWipe = true }
        } footer: {
            Text("Writes to the Dev store only — this build has no entitlement for the production App Group.")
        }
        .confirmationDialog("Wipe every match?", isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("Wipe", role: .destructive) {}
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Variant A — Buried in Settings

/// The row that goes at the bottom of the real Settings `Form`.
struct PrototypeVariantASettingsSection: View {
    var body: some View {
        Section("Developer") {
            NavigationLink {
                PrototypeDevToolsScreen()
            } label: {
                Label("Dev Tools", systemImage: "hammer")
            }
        }
    }
}

/// A's answer to B's tile dock: the tools live in a `TabView`, so the screen
/// switches between them rather than only ever showing the seeder. The two
/// empty slots stand in for tools not written yet — the same signal B's dashed
/// tiles carry.
enum PrototypeTool: String, CaseIterable, Identifiable, Hashable {
    case seeder = "Seeder"
    case toolTwo = "Tool 2"
    case toolThree = "Tool 3"
    case toolFour = "Tool 4"
    case toolFive = "Tool 5"
    case toolSix = "Tool 6"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .seeder:    return "wand.and.stars"
        case .toolTwo:   return "wrench.and.screwdriver"
        case .toolThree: return "ellipsis.curlybraces"
        case .toolFour:  return "ladybug"
        case .toolFive:  return "square.and.arrow.up.on.square"
        case .toolSix:   return "gauge.with.dots.needle.bottom.50percent"
        }
    }
}

struct PrototypeDevToolsScreen: View {
    @State private var params = PrototypeSeederParameters()
    @State private var tool: PrototypeTool = .seeder

    var body: some View {
        // The stock `TabView` already renders as Liquid Glass on iOS 26 — the
        // hand-rolled `GlassEffectContainer` bar this replaces was reimplementing
        // what the platform gives for free, and worse: no minimize-on-scroll, no
        // automatic safe-area inset for the content beneath.
        TabView(selection: $tool) {
            Tab("Seeder", systemImage: PrototypeTool.seeder.icon, value: PrototypeTool.seeder) {
                Form {
                    PrototypeSeederForm(params: $params)
                }
                .navigationTitle("Seeder")
            }

            // Five empty slots rather than two: the point of this round is to see
            // what the bar does once the tool count passes what fits, since a dev
            // tools screen only ever grows.
            ForEach(PrototypeTool.allCases.dropFirst()) { item in
                Tab(item.rawValue, systemImage: item.icon, value: item) {
                    placeholderTool
                        .navigationTitle(item.rawValue)
                }
            }
        }
        // The bar shrinks to a pill as the form scrolls away — which is exactly
        // the fix for the occlusion the hand-rolled bar had over the Seeder's
        // last footer.
        .tabBarMinimizeBehavior(.onScrollDown)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var placeholderTool: some View {
        ContentUnavailableView(
            "No tool here yet",
            systemImage: "wrench.and.screwdriver",
            description: Text("A future dev tool drops in beside the Seeder.")
        )
    }
}

// MARK: - Variant B — Floating bubble

/// A draggable bubble that floats over whatever screen is showing, expanding
/// into a panel laid out as a **dock of tools** rather than a settings form —
/// the seeder is the first tile, with room for the next tool beside it.
struct PrototypeVariantBBubble: View {
    @State private var offset: CGSize = .zero
    @State private var accumulated: CGSize = CGSize(width: 0, height: -120)
    @State private var showPanel = false

    var body: some View {
        Image(systemName: "hammer.fill")
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(Circle().fill(Color.indigo))
            .overlay(
                Text("DEV")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .offset(y: 20)
            )
            .shadow(radius: 6)
            .offset(
                x: accumulated.width + offset.width,
                y: accumulated.height + offset.height
            )
            .gesture(
                DragGesture()
                    .onChanged { offset = $0.translation }
                    .onEnded { _ in
                        accumulated.width += offset.width
                        accumulated.height += offset.height
                        offset = .zero
                    }
            )
            .onTapGesture { showPanel = true }
            .sheet(isPresented: $showPanel) {
                PrototypeDevToolsPanel()
                    .presentationDetents([.medium, .large])
            }
    }
}

/// The dock layout: tools as tiles, the selected one expanding below. This is
/// what makes B structurally different from A and C — it is built to grow.
struct PrototypeDevToolsPanel: View {
    @State private var params = PrototypeSeederParameters()
    @State private var selected: String? = "seeder"

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                // Wipe is not a tool of its own — it is the Seeder's
                // counterpart, so it lives as a button inside the Seeder's
                // form rather than as a tile. That also drops the dock to a
                // single clean row.
                LazyVGrid(columns: columns, spacing: 12) {
                    tile("seeder", "Seeder", "wand.and.stars", .indigo)
                    placeholderTile
                    placeholderTile
                }
                .padding(.horizontal)

                if selected == "seeder" {
                    Form {
                        PrototypeSeederForm(params: $params)
                    }
                    .frame(height: 760)
                    .scrollDisabled(true)
                }
            }
            .navigationTitle("Dev Tools")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func tile(_ id: String, _ label: String, _ icon: String, _ tint: Color) -> some View {
        Button { selected = (selected == id) ? nil : id } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(tint.opacity(selected == id ? 0.25 : 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(tint, lineWidth: selected == id ? 2 : 0)
            )
            .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }

    /// Deliberately visible: the point of the dock is that the next tool has an
    /// obvious place to land.
    private var placeholderTile: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.title2)
            Text("Tool")
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .foregroundStyle(.tertiary)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                .foregroundStyle(.tertiary)
        )
    }
}

// MARK: - Variant C — Toolbar item

struct PrototypeVariantCToolbarButton: View {
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Image(systemName: "hammer")
        }
        .sheet(isPresented: $showSheet) {
            NavigationStack {
                PrototypeDevToolsScreen()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showSheet = false }
                        }
                    }
            }
        }
    }
}

#endif
