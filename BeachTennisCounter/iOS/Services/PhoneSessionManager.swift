import Foundation
import WatchConnectivity
import SwiftUI
import SwiftData

@MainActor
final class PhoneSessionManager: NSObject, ObservableObject {
    static let shared = PhoneSessionManager()

    @AppStorage("teamAColorHex") var teamAColorHex: String = WatchSettings.defaultTeamAColorHex
    @AppStorage("teamBColorHex") var teamBColorHex: String = WatchSettings.defaultTeamBColorHex
    /// Persisted as its raw token — `@AppStorage` stores a `RawRepresentable`
    /// by its raw value, and hands back the default for anything it can't
    /// decode, which is the same fallback `SportSetting(storedToken:)` applies.
    @AppStorage("sportSetting") var sportSetting: SportSetting = WatchSettings.defaultSportSetting
    @AppStorage("teamAName") var teamAName: String = WatchSettings.defaultTeamAName
    @AppStorage("teamBName") var teamBName: String = WatchSettings.defaultTeamBName
    @AppStorage("healthMonitoringEnabled") var healthMonitoringEnabled: Bool = WatchSettings.defaultHealthMonitoringEnabled

    /// Last-known HealthKit authorization status reported by the watch, persisted
    /// raw. The phone can't query the watch's grant directly; the watch pushes it
    /// on change. `.denied` drives the Settings toggle into its disabled override.
    @AppStorage("watchHealthAuthStatus") var watchHealthAuthStatusRaw: String = HealthAuthStatus.undetermined.rawValue

    var watchHealthAuthStatus: HealthAuthStatus {
        HealthAuthStatus(rawValue: watchHealthAuthStatusRaw) ?? .undetermined
    }

    /// nil = session not yet activated (unknown); true/false = known state
    @Published private(set) var isWatchAppInstalled: Bool? = nil

    private var modelContext: ModelContext?

    func setModelContainer(_ container: ModelContainer) {
        modelContext = ModelContext(container)
    }

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    /// The setting Pro gates — Vários, the watch asking which sport before each
    /// match.
    nonisolated static let proOnlySportSetting = SportSetting.multiple

    /// The sport setting that actually applies, which is not always the stored
    /// one: Vários is a Pro feature, so without Pro this reports the default
    /// instead.
    ///
    /// The gate sits at the point of *use* rather than only at the picker, and
    /// deliberately does not rewrite storage. Someone who chose Vários in
    /// 1.4/1.5 — while it was free — keeps that choice written down: switching
    /// the flag on takes the behaviour away (the regression this release
    /// accepted) and buying Pro hands it straight back with nothing to re-pick.
    /// Gating the picker alone would have left exactly those users, the ones
    /// the regression names, using a paid feature forever.
    ///
    /// Pure and static so both answers are testable — including the dark one,
    /// where `isPro` is `true` for everybody and this is the identity.
    nonisolated static func effectiveSportSetting(_ stored: SportSetting, isPro: Bool) -> SportSetting {
        guard stored == proOnlySportSetting, !isPro else { return stored }
        return WatchSettings.defaultSportSetting
    }

    /// The settings the watch consumes, as currently stored on the phone —
    /// except for `sportSetting`, which is what the entitlement allows. The
    /// watch is told the effective value because it cannot work one out: it
    /// links no StoreKit and knows nothing about Pro (ADR 0004).
    var watchSettings: WatchSettings {
        WatchSettings(teamAColorHex: teamAColorHex,
                      teamBColorHex: teamBColorHex,
                      sportSetting: Self.effectiveSportSetting(
                          sportSetting,
                          isPro: ProEntitlement.shared.isPro
                      ),
                      teamAName: teamAName,
                      teamBName: teamBName,
                      healthMonitoringEnabled: healthMonitoringEnabled,
                      rulesetsBlob: encodedActiveRulesets)
    }

    /// The active Ruleset for every sport, encoded as a blob dictionary. Before
    /// any Ruleset editing UI exists every sport uses its built-in preset, so
    /// the dictionary is empty and the watch falls back to presets — no encoding
    /// traffic for something the watch already knows.
    private var encodedActiveRulesets: [String: Data] {
        [:]
    }

    func pushSettingsToWatch() {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else { return }
        try? WCSession.default.updateApplicationContext(watchSettings.toApplicationContext())
    }
}

extension PhoneSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        let installed = session.isWatchAppInstalled
        let status = HealthAuthStatusMessage.status(from: session.receivedApplicationContext)
        Task { @MainActor in
            isWatchAppInstalled = installed
            if let status { watchHealthAuthStatusRaw = status.rawValue }
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let installed = session.isWatchAppInstalled
        Task { @MainActor in isWatchAppInstalled = installed }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        insertMatch(from: message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        insertMatch(from: userInfo)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // The watch→phone channel carries only the HealthKit auth status. Decode
        // the Sendable value before crossing onto the main actor; an unrecognized
        // or absent value returns nil and leaves the persisted status untouched.
        guard let status = HealthAuthStatusMessage.status(from: applicationContext) else { return }
        Task { @MainActor in watchHealthAuthStatusRaw = status.rawValue }
    }

    private nonisolated func insertMatch(from dict: [String: Any]) {
        guard dict[WatchMessageKey.type] as? String == WatchMessageType.matchResult,
              let payload = MatchResultPayload.from(dict) else { return }

        Task { @MainActor in
            guard let context = modelContext else { return }
            let matchId = payload.matchId
            let existing = FetchDescriptor<StoredMatch>(
                predicate: #Predicate { $0.id == matchId }
            )
            if let count = try? context.fetchCount(existing), count > 0 { return }
            let gameData = (try? JSONEncoder().encode(payload.gameHistory)) ?? Data()
            let setData = (try? JSONEncoder().encode(payload.setHistory)) ?? Data()
            let match = StoredMatch(
                id: payload.matchId,
                date: payload.date,
                setScoreA: payload.setScoreA,
                setScoreB: payload.setScoreB,
                setsWonA: payload.setsWonA,
                setsWonB: payload.setsWonB,
                winner: payload.winner.rawValue,
                duration: payload.duration,
                gameHistoryData: gameData,
                setHistoryData: setData,
                matchTypeRaw: payload.matchType.rawValue,
                teamAName: payload.teamAName,
                teamBName: payload.teamBName,
                activeCalories: payload.activeCalories,
                avgHeartRate: payload.avgHeartRate,
                rulesetData: payload.rulesetData
            )
            context.insert(match)
            try? context.save()
        }
    }
}

// MARK: - Color hex helpers (iOS side)

extension Color {
    func toHex() -> String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: nil)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    /// Non-failable on purpose: the phone decodes its own literals and its own
    /// stored values, so every call site here has a colour or the app is already
    /// broken. Parsing itself lives in `HexColor`.
    init(hex: String) {
        guard let rgb = HexColor.components(hex) else {
            self = .black
            return
        }
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
