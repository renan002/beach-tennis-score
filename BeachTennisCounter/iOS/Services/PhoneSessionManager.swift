import Foundation
import WatchConnectivity
import SwiftUI
import SwiftData

@MainActor
final class PhoneSessionManager: NSObject, ObservableObject {
    static let shared = PhoneSessionManager()

    @AppStorage("teamAColorHex") var teamAColorHex: String = "E74C3C"
    @AppStorage("teamBColorHex") var teamBColorHex: String = "5B8DEF"
    @AppStorage("sportSetting") var sportSetting: String = "beachTennis"

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

    func pushColorsToWatch() {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else { return }
        try? WCSession.default.updateApplicationContext([
            WatchMessageKey.teamAColor: teamAColorHex,
            WatchMessageKey.teamBColor: teamBColorHex,
            WatchMessageKey.sportSetting: sportSetting
        ])
    }

    func pushSettingsToWatch() {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else { return }
        try? WCSession.default.updateApplicationContext([
            WatchMessageKey.teamAColor: teamAColorHex,
            WatchMessageKey.teamBColor: teamBColorHex,
            WatchMessageKey.sportSetting: sportSetting
        ])
    }
}

extension PhoneSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        let installed = session.isWatchAppInstalled
        Task { @MainActor in isWatchAppInstalled = installed }
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

    private nonisolated func insertMatch(from dict: [String: Any]) {
        guard dict[WatchMessageKey.type] as? String == WatchMessageType.matchResult,
              let payload = MatchResultPayload.from(dict) else { return }

        Task { @MainActor in
            guard let context = modelContext else { return }
            let gameData = (try? JSONEncoder().encode(payload.gameHistory)) ?? Data()
            let setData = (try? JSONEncoder().encode(payload.setHistory)) ?? Data()
            let match = StoredMatch(
                date: payload.date,
                setScoreA: payload.setScoreA,
                setScoreB: payload.setScoreB,
                setsWonA: payload.setsWonA,
                setsWonB: payload.setsWonB,
                winner: payload.winner.rawValue,
                duration: payload.duration,
                gameHistoryData: gameData,
                setHistoryData: setData,
                matchTypeRaw: payload.matchType.rawValue
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
