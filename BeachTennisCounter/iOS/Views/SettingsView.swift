import SwiftUI

private let colorOptions: [(name: String, hex: String, color: Color)] = [
    ("Red",    "E74C3C", Color(hex: "E74C3C")),
    ("Blue",   "5B8DEF", Color(hex: "5B8DEF")),
    ("Green",  "2ECC71", Color(hex: "2ECC71")),
    ("Orange", "E67E22", Color(hex: "E67E22")),
    ("Purple", "9B59B6", Color(hex: "9B59B6")),
]

struct SettingsView: View {
    @EnvironmentObject private var phoneSession: PhoneSessionManager
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("sportSetting") private var sportSetting: String = "beachTennis"
    @Environment(\.dismiss) private var dismiss
    @State private var originalColorA = ""
    @State private var originalColorB = ""
    @State private var originalSport = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Modality", selection: $sportSetting) {
                        Text("Beach Tennis").tag("beachTennis")
                        Text("Tennis").tag("tennis")
                        Text("Multiple").tag("multiple")
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Sport")
                } footer: {
                    Text(sportSettingFooter)
                }

                Section("Team Colors") {
                    colorPicker(label: "Team A", hexBinding: $phoneSession.teamAColorHex)
                    colorPicker(label: "Team B", hexBinding: $phoneSession.teamBColorHex)
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appTheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        syncToWatchIfChanged()
                        dismiss()
                    }
                }
            }
            .preferredColorScheme(colorScheme)
            .onAppear {
                originalColorA = phoneSession.teamAColorHex
                originalColorB = phoneSession.teamBColorHex
                originalSport = sportSetting
            }
            .onDisappear {
                syncToWatchIfChanged()
            }
            .safeAreaInset(edge: .bottom) {
                Text("Version \(appVersion)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)
            }
        }
    }

    private var sportSettingFooter: String {
        switch sportSetting {
        case "tennis":    return "The Watch will always start a Tennis match."
        case "multiple":  return "The Watch will ask which sport before each match."
        default:          return "The Watch will always start a Beach Tennis match."
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    @ViewBuilder
    private func colorPicker(label: LocalizedStringKey, hexBinding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(colorOptions, id: \.hex) { option in
                    let isSelected = hexBinding.wrappedValue == option.hex
                    Circle()
                        .fill(option.color)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: isSelected ? 3 : 0)
                                .padding(-3)
                        )
                        .onTapGesture {
                            hexBinding.wrappedValue = option.hex
                        }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func syncToWatchIfChanged() {
        let colorsChanged = phoneSession.teamAColorHex != originalColorA
            || phoneSession.teamBColorHex != originalColorB
        let sportChanged = sportSetting != originalSport
        guard colorsChanged || sportChanged else { return }
        phoneSession.pushSettingsToWatch()
        // Refresh baselines so a later onDisappear doesn't double-push.
        originalColorA = phoneSession.teamAColorHex
        originalColorB = phoneSession.teamBColorHex
        originalSport = sportSetting
    }
}
