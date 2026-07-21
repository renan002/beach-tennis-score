import Foundation
import WatchConnectivity
import SwiftUI
import SwiftData

@MainActor
final class PhoneSessionManager: NSObject, ObservableObject {
    static let shared = PhoneSessionManager()

    @AppStorage("teamAColorHex") var teamAColorHex: String = WatchSettings.defaultTeamAColorHex
    @AppStorage("teamBColorHex") var teamBColorHex: String = WatchSettings.defaultTeamBColorHex
    @AppStorage("sportSetting") var sportSetting: String = WatchSettings.defaultSportSetting
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

    /// The settings the watch consumes, as currently stored on the phone.
    var watchSettings: WatchSettings {
        WatchSettings(teamAColorHex: teamAColorHex,
                      teamBColorHex: teamBColorHex,
                      sportSetting: sportSetting,
                      teamAName: teamAName,
                      teamBName: teamBName,
                      healthMonitoringEnabled: healthMonitoringEnabled)
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
                avgHeartRate: payload.avgHeartRate
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

    init(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else {
            self = .black
            return
        }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
