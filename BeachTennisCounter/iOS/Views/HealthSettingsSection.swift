import SwiftUI

/// The Settings "Health" section: the single Health Monitoring toggle, preceded
/// by what the Watch actually records once it's on.
///
/// Shape chosen by the #102 prototype (variant B — "Explained"): stating the
/// three things that get recorded *before* asking for the toggle reads as an
/// informed choice rather than a bare permission request. Denied collapses the
/// card back to title + denied footer, since nothing is being recorded to list.
struct HealthSettingsSection: View {
    /// Binds to the stored setting when usable. While the Watch reports denied
    /// the caller passes a constant `false` — a display override, not an
    /// overwrite, so the user's real choice resumes on re-grant.
    @Binding var isOn: Bool
    let isDenied: Bool

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
                        Text(footer)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Toggle("Health Monitoring", isOn: $isOn)
                        .labelsHidden()
                        .disabled(isDenied)
                }

                if !isDenied {
                    VStack(alignment: .leading, spacing: 6) {
                        recordedRow("heart.fill", "Live heart rate during the match")
                        recordedRow("flame.fill", "Active calories, saved to Match History")
                        recordedRow("figure.tennis", "The match saved as a workout in Health")
                    }
                    .padding(.leading, 2)
                    // Dimmed rather than hidden while off: the list is what the
                    // toggle turns on, so it stays legible as the explanation.
                    .opacity(isOn ? 1 : 0.4)
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("Health")
        }
    }

    private var footer: String {
        if isDenied {
            return String(localized: "Health access was denied on the Watch. To re-enable it, open Settings › Privacy & Security › Health.")
        }
        return String(localized: "The Watch records each match as a workout with live heart rate.")
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
