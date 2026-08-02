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
    @EnvironmentObject private var pro: ProEntitlement
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("sportSetting") private var sportSetting: SportSetting = WatchSettings.defaultSportSetting
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var syncedSettings: WatchSettings?
    @State private var quarantines: [QuarantinedStore] = []
    @State private var liveMatchIDs: Set<UUID> = []
    @State private var showProSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Modality", selection: sportBinding) {
                        ForEach(SportSetting.allCases, id: \.self) { setting in
                            sportOption(setting)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Sport")
                } footer: {
                    // The effective setting, matching the picker: promising that
                    // the watch will ask before each match would be a lie while
                    // Vários is locked.
                    Text(effectiveSportSetting.settingsFooter)
                }

                Section("Teams") {
                    teamRow(label: "Team A",
                            nameBinding: $phoneSession.teamAName,
                            hexBinding: $phoneSession.teamAColorHex)
                    teamRow(label: "Team B",
                            nameBinding: $phoneSession.teamBName,
                            hexBinding: $phoneSession.teamBColorHex)
                }

                HealthSettingsSection(
                    isOn: healthMonitoringBinding,
                    isDenied: isHealthDenied
                )

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

                proSection

                Section("About") {
                    Link(destination: Self.privacyPolicyURL) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            // Not a chevron: this leaves the app for Safari, and
                            // `Link` tints the whole label so the glyph reads as
                            // part of the affordance rather than a disclosure.
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }

                // Last, so the dev flavor's extra section never pushes a real
                // setting off the first screen. Absent from every other build.
                #if DEV_FLAVOR
                DevToolsSettingsSection()
                #endif
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
            .sheet(isPresented: $showProSheet) {
                ProPurchaseSheet()
                    .environmentObject(pro)
            }
            .task { reloadQuarantines() }
            .onAppear {
                syncedSettings = phoneSession.watchSettings
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

    // MARK: - Pro

    /// The Pro section: what the unlock is worth today (nothing is gated yet),
    /// and — the part this ticket owes the App Store — a Restore Purchases
    /// action that a buyer on a new iPhone can find without having hit a gate.
    ///
    /// **Absent entirely from a dark build**, Restore included. That is the
    /// section's half of "no purchase affordance anywhere", and it needs no
    /// guard on `ProPurchaseSheet` itself: the other thing that can raise
    /// `showProSheet` is the locked Vários option, which is unlocked for
    /// everybody in a dark build because `isPro` is. Every purchase affordance
    /// in the app is guarded where it is *produced*, never at the sheet.
    ///
    /// Hiding Restore rather than keeping it standing alone was decided in "Does
    /// the dark flag silence StoreKit entirely?": guideline 3.1.1 scopes the
    /// Restore duty to *restorable* purchases, which a build selling nothing
    /// does not have. It also completes the promise that a dark build makes no
    /// App Store traffic — `AppStore.sync()` was the last thing a user could
    /// still have triggered by hand.
    @ViewBuilder
    private var proSection: some View {
        if FeatureFlags.proOnSale {
            Section {
                if pro.ownsPro {
                    LabeledContent("Pro", value: String(localized: "Unlocked"))
                } else {
                    Button("Unlock Pro") { showProSheet = true }
                }

                RestorePurchasesButton()
            } header: {
                Text("Pro")
            } footer: {
                Text(ProPurchaseSheet.pitch(ownsPro: pro.ownsPro))
            }
        }
    }

    // MARK: - About

    /// The published privacy policy — App Store guideline 5.1.1 requires it to be
    /// reachable from inside the app, not only from the App Store listing.
    ///
    /// GitHub Pages serves `privacy-policy.md` from the repo root of `main`, so
    /// the document and the app ship from the same source: edit the Markdown and
    /// this link follows. Force-unwrapped because a literal that fails to parse
    /// is a typo to catch on first launch, not a condition to handle.
    private static let privacyPolicyURL = URL(
        string: "https://renan002.github.io/beach-tennis-score/privacy-policy"
    )!

    private func reloadQuarantines() {
        quarantines = StoreRecovery.listQuarantinedStores(in: LiveStore.directory)
        let ids = (try? modelContext.fetch(FetchDescriptor<StoredMatch>()))?.map(\.id) ?? []
        liveMatchIDs = Set(ids)
    }

    // MARK: - Modality

    /// One row per setting, all of them named by the type. Vários is locked for
    /// free users: it stays visible in the menu — the point of a
    /// locked-but-visible option is that it advertises what Pro buys — with a
    /// padlock rather than a checkmark's worth of silence.
    @ViewBuilder
    private func sportOption(_ setting: SportSetting) -> some View {
        if setting == PhoneSessionManager.proOnlySportSetting && !pro.isPro {
            Label(setting.displayName, systemImage: "lock.fill").tag(setting)
        } else {
            Text(setting.displayName).tag(setting)
        }
    }

    /// The picker's selection, gated in both directions.
    ///
    /// Reading reports the *effective* setting, so a free user who chose Vários
    /// back when it was free sees the sport the watch is actually going to
    /// start rather than one the app is quietly ignoring. Writing refuses
    /// Vários without Pro and opens the purchase sheet instead — the
    /// tap-through — leaving the stored choice untouched, so a purchase later
    /// restores it with nothing to re-pick.
    ///
    /// Note it reads `pro.isPro`, never the flag: in a dark build `isPro` is
    /// `true` for everybody, so the lock, the padlock and the tap-through all
    /// disappear on their own and Vários is freely selectable exactly as it is
    /// today.
    private var sportBinding: Binding<SportSetting> {
        Binding(
            get: { effectiveSportSetting },
            set: { selected in
                guard selected != PhoneSessionManager.proOnlySportSetting || pro.isPro else {
                    showProSheet = true
                    return
                }
                sportSetting = selected
            }
        )
    }

    /// The setting that actually applies — the stored one unless Pro is gating
    /// it. Storage stays a raw token; everything read off it is the type.
    private var effectiveSportSetting: SportSetting {
        PhoneSessionManager.effectiveSportSetting(sportSetting, isPro: pro.isPro)
    }

    /// The version string for the Settings footer, carrying a `DEV` marker on
    /// dev-flavor builds so a screenshot or a bug report says which app produced
    /// it. Deliberately composed into the *interpolated value*, not the copy:
    /// the `Version %@` catalog key is left untouched, and `DEV` — a build
    /// identifier, not prose — stays untranslated in every locale.
    ///
    /// Settings is the only place this appears. It must never reach the scoring
    /// screens or the Cartão de Resultado, which is an image made to be posted.
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        #if DEV_FLAVOR
        return "\(version) · DEV"
        #else
        return version
        #endif
    }

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

    /// Wraps a name binding so typed/pasted input is hard-capped, per
    /// `TeamName.capped`. Trimming happens later, on commit.
    private func cappedName(_ source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue },
            set: { source.wrappedValue = TeamName.capped($0) }
        )
    }

    /// Puts committed names into their canonical stored form. Runs at the commit
    /// points (Done / onDisappear) rather than per-keystroke so the field stays
    /// natural to type in.
    private func commitNames() {
        phoneSession.teamAName = TeamName.committed(phoneSession.teamAName)
        phoneSession.teamBName = TeamName.committed(phoneSession.teamBName)
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
