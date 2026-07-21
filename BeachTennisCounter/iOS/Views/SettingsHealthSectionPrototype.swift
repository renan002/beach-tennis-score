// PROTOTYPE — throwaway. Lives on branch prototype/102-health-toggle only.
// Never merge to develop; fold the winning variant in by hand.
//
// QUESTION
// --------
// Three structurally different takes on issue #102's Health section, mounted on
// the real Settings screen (sub-shape A) so they're judged against the real
// Sport/Teams/Appearance sections around them, not in a vacuum:
//
//   A — Bare row      the shipped shape: one Toggle + a footer sentence.
//   B — Explained     a card that says what gets recorded before asking.
//   C — Status-first  leads with the watch's live Health state; toggle is secondary.
//
// The floating bar at the bottom cycles variants AND fakes the watch's reported
// auth status, so the denied override can be judged without a real watch.

import SwiftUI

// MARK: - Prototype harness state

@MainActor
final class HealthSectionPrototype: ObservableObject {
    enum Variant: String, CaseIterable {
        case a = "A", b = "B", c = "C"

        var name: String {
            switch self {
            case .a: return "Bare row"
            case .b: return "Explained"
            case .c: return "Status-first"
            }
        }
    }

    @Published var variant: Variant = .a
    /// Overrides `PhoneSessionManager.watchHealthAuthStatus` for the prototype only.
    @Published var fakedStatus: HealthAuthStatus = .granted

    func cycle(by offset: Int) {
        let all = Variant.allCases
        let i = (all.firstIndex(of: variant)! + offset + all.count) % all.count
        variant = all[i]
    }
}

// MARK: - Shared bits (deliberately tiny — variants must be free to disagree on layout)

private func normalFooter() -> String {
    String(localized: "The Watch records each match as a workout with live heart rate.")
}

private func deniedFooter() -> String {
    String(localized: "Health access was denied on the Watch. To re-enable it, open Settings › Privacy & Security › Health.")
}

// MARK: - Variant A — Bare row (what ships today)

struct HealthSectionVariantA: View {
    @Binding var isOn: Bool
    let denied: Bool

    var body: some View {
        Section {
            Toggle("Health Monitoring", isOn: denied ? .constant(false) : $isOn)
                .disabled(denied)
        } header: {
            Text("Health")
        } footer: {
            Text(denied ? deniedFooter() : normalFooter())
        }
    }
}

// MARK: - Variant B — Explained card

struct HealthSectionVariantB: View {
    @Binding var isOn: Bool
    let denied: Bool

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.title2)
                        .foregroundStyle(.pink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Health Monitoring")
                            .font(.headline)
                        Text(denied ? deniedFooter() : normalFooter())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Toggle("", isOn: denied ? .constant(false) : $isOn)
                        .labelsHidden()
                        .disabled(denied)
                }

                if !denied {
                    VStack(alignment: .leading, spacing: 6) {
                        recordedRow("heart.fill", "Live heart rate during the match")
                        recordedRow("flame.fill", "Active calories, saved to Match History")
                        recordedRow("figure.tennis", "The match saved as a workout in Health")
                    }
                    .padding(.leading, 2)
                    .opacity(isOn ? 1 : 0.4)
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("Health")
        }
    }

    private func recordedRow(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.caption)
                .frame(width: 16)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Variant C — Status-first

struct HealthSectionVariantC: View {
    @Binding var isOn: Bool
    let status: HealthAuthStatus

    private var denied: Bool { status == .denied }

    var body: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: statusSymbol)
                    .foregroundStyle(statusTint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(statusTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            Toggle("Health Monitoring", isOn: denied ? .constant(false) : $isOn)
                .disabled(denied)

            if denied {
                Label("Settings › Privacy & Security › Health", systemImage: "gearshape")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Health")
        }
    }

    private var statusSymbol: String {
        switch status {
        case .granted:      return isOn ? "applewatch.watchface" : "applewatch.slash"
        case .denied:       return "hand.raised.fill"
        case .undetermined: return "questionmark.circle"
        }
    }

    private var statusTint: Color {
        switch status {
        case .granted:      return isOn ? .green : .secondary
        case .denied:       return .red
        case .undetermined: return .orange
        }
    }

    private var statusTitle: String {
        switch status {
        case .granted:      return isOn ? String(localized: "Recording on Apple Watch")
                                        : String(localized: "Not recording")
        case .denied:       return String(localized: "Health access denied on the Watch")
        case .undetermined: return String(localized: "The Watch will ask at your next match")
        }
    }

    private var statusDetail: String {
        status == .denied ? deniedFooter() : normalFooter()
    }
}

// MARK: - Floating switcher bar

struct HealthPrototypeBar: View {
    @ObservedObject var proto: HealthSectionPrototype

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Button { proto.cycle(by: -1) } label: { Image(systemName: "chevron.left") }
                Text("\(proto.variant.rawValue) — \(proto.variant.name)")
                    .font(.footnote.monospaced().weight(.semibold))
                    .frame(minWidth: 150)
                Button { proto.cycle(by: 1) } label: { Image(systemName: "chevron.right") }
            }
            Picker("Watch reports", selection: $proto.fakedStatus) {
                ForEach(HealthAuthStatus.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.white)
        .tint(.white)
        .shadow(radius: 8)
        .padding(.horizontal, 24)
    }
}
