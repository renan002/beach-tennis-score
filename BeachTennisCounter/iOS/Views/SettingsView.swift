import SwiftUI
import SwiftData

private let colorOptions: [(name: String, hex: String, color: Color)] = [
    ("Red",    "E74C3C", Color(hex: "E74C3C")),
    ("Blue",   "5B8DEF", Color(hex: "5B8DEF")),
    ("Green",  "2ECC71", Color(hex: "2ECC71")),
    ("Orange", "E67E22", Color(hex: "E67E22")),
    ("Purple", "9B59B6", Color(hex: "9B59B6")),
]

struct SettingsView: View {
    @EnvironmentObject private var phoneSession: PhoneSessionManager
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("sportSetting") private var sportSetting: String = "beachTennis"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var syncedSettings: WatchSettings?
    @State private var quarantines: [QuarantinedStore] = []
    @State private var liveMatchIDs: Set<UUID> = []
    /// PROTOTYPE (#102) — variant + faked watch auth status. Remove with the switch below.
    @StateObject private var proto = HealthSectionPrototype()

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

                Section("Teams") {
                    teamRow(label: "Team A",
                            nameBinding: $phoneSession.teamAName,
                            hexBinding: $phoneSession.teamAColorHex)
                    teamRow(label: "Team B",
                            nameBinding: $phoneSession.teamBName,
                            hexBinding: $phoneSession.teamBColorHex)
                }

                // PROTOTYPE (#102, branch prototype/102-health-toggle): the three
                // Health-section variants replace the shipped section. Revert this
                // hunk when the prototype is done.
                switch proto.variant {
                case .a:
                    HealthSectionVariantA(isOn: $phoneSession.healthMonitoringEnabled,
                                          denied: proto.fakedStatus == .denied)
                case .b:
                    HealthSectionVariantB(isOn: $phoneSession.healthMonitoringEnabled,
                                          denied: proto.fakedStatus == .denied)
                case .c:
                    HealthSectionVariantC(isOn: $phoneSession.healthMonitoringEnabled,
                                          status: proto.fakedStatus)
                }

                if !quarantines.isEmpty {
                    QuarantinedStoresSection(
                        quarantines: quarantines,
                        liveMatchIDs: liveMatchIDs,
                        reload: reloadQuarantines
                    )
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
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
            .task { reloadQuarantines() }
            .onAppear {
                syncedSettings = phoneSession.watchSettings
            }
            .onDisappear {
                syncToWatchIfChanged()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Text("Version \(appVersion)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    // PROTOTYPE (#102) — variant switcher. Remove with the switch above.
                    HealthPrototypeBar(proto: proto)
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func reloadQuarantines() {
        quarantines = StoreRecovery.listQuarantinedStores(in: LiveStore.directory)
        let ids = (try? modelContext.fetch(FetchDescriptor<StoredMatch>()))?.map(\.id) ?? []
        liveMatchIDs = Set(ids)
    }

    private var sportSettingFooter: String {
        switch sportSetting {
        case "tennis":    return String(localized: "The Watch will always start a Tennis match.")
        case "multiple":  return String(localized: "The Watch will ask which sport before each match.")
        default:          return String(localized: "The Watch will always start a Beach Tennis match.")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    /// Name length cap: keeps the watch serve buttons and history lines from
    /// truncating. Counts grapheme clusters, so a 12-emoji name is still 12.
    private static let nameMaxLength = 12

    /// The watch last reported that Health access was denied on-watch.
    private var isHealthDenied: Bool {
        phoneSession.watchHealthAuthStatus == .denied
    }

    /// A display override, not an overwrite: while denied the toggle reads off and
    /// is disabled, but the stored setting is left untouched — so on re-grant the
    /// user's real choice auto-resumes. Otherwise it binds to the stored setting.
    private var healthMonitoringBinding: Binding<Bool> {
        if isHealthDenied {
            return .constant(false)
        }
        return $phoneSession.healthMonitoringEnabled
    }

    private var healthFooter: String {
        if isHealthDenied {
            return String(localized: "Health access was denied on the Watch. To re-enable it, open Settings › Privacy & Security › Health.")
        }
        return String(localized: "The Watch records each match as a workout with live heart rate.")
    }

    @ViewBuilder
    private func teamRow(
        label: LocalizedStringKey,
        nameBinding: Binding<String>,
        hexBinding: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Name", text: cappedName(nameBinding))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

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

    /// Wraps a name binding so typed/pasted input is hard-capped at
    /// `nameMaxLength` characters. Trimming happens later, on commit.
    private func cappedName(_ source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue },
            set: { source.wrappedValue = String($0.prefix(Self.nameMaxLength)) }
        )
    }

    /// Trims committed names to their canonical stored form: surrounding
    /// whitespace stripped, whitespace-only collapsing to empty. Runs at the
    /// commit points (Done / onDisappear) rather than per-keystroke so the
    /// field stays natural to type in.
    private func commitNames() {
        phoneSession.teamAName = phoneSession.teamAName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        phoneSession.teamBName = phoneSession.teamBName
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func syncToWatchIfChanged() {
        commitNames()
        let current = phoneSession.watchSettings
        guard current != syncedSettings else { return }
        phoneSession.pushSettingsToWatch()
        // Refresh the baseline so a later onDisappear doesn't double-push.
        syncedSettings = current
    }
}
