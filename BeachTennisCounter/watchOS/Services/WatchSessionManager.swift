import Foundation
import WatchConnectivity
import SwiftUI

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var teamAColor: Color = .red
    @Published var teamBColor: Color = .blue
    @Published var sportSetting: String = "beachTennis"

    private nonisolated static let pendingResultKey = "pendingMatchResult"

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func sendMatchResult(_ state: MatchState, duration: TimeInterval) {
        guard let winner = state.winner else { return }

        let payload = MatchResultPayload(
            matchId: UUID(),
            setScoreA: state.setScoreA,
            setScoreB: state.setScoreB,
            setsWonA: state.setsWonA,
            setsWonB: state.setsWonB,
            winner: winner,
            duration: duration,
            date: Date(),
            gameHistory: state.gameHistory,
            setHistory: state.setHistory,
            matchType: state.matchType,
            teamAName: state.teamAName,
            teamBName: state.teamBName
        )

        guard WCSession.default.activationState == .activated else {
            if let data = try? JSONEncoder().encode(payload) {
                UserDefaults.standard.set(data, forKey: Self.pendingResultKey)
            }
            return
        }
        deliver(payload)
    }

    private func deliver(_ payload: MatchResultPayload) {
        let dict = payload.toDictionary()
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(dict, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(dict)
            }
        } else {
            WCSession.default.transferUserInfo(dict)
        }
    }

    private func apply(_ settings: WatchSettings) {
        teamAColor = Color(hex: settings.teamAColorHex) ?? .red
        teamBColor = Color(hex: settings.teamBColorHex) ?? .blue
        sportSetting = settings.sportSetting
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if activationState == .activated,
           let data = UserDefaults.standard.data(forKey: Self.pendingResultKey),
           let payload = try? JSONDecoder().decode(MatchResultPayload.self, from: data) {
            UserDefaults.standard.removeObject(forKey: Self.pendingResultKey)
            WCSession.default.transferUserInfo(payload.toDictionary())
        }

        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }
        let settings = WatchSettings.from(context)
        Task { @MainActor in apply(settings) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard !applicationContext.isEmpty else { return }
        let settings = WatchSettings.from(applicationContext)
        Task { @MainActor in apply(settings) }
    }
}

// MARK: - Color hex helper (watch-side: decode only)

extension Color {
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
