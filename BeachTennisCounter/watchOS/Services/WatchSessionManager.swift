import Foundation
import WatchConnectivity
import SwiftUI

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var teamAColor: Color = .red
    @Published var teamBColor: Color = .blue

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func sendMatchResult(_ state: MatchState, duration: TimeInterval) {
        guard WCSession.default.activationState == .activated,
              let winner = state.winner else { return }

        let payload = MatchResultPayload(
            setScoreA: state.setScoreA,
            setScoreB: state.setScoreB,
            winner: winner,
            duration: duration,
            date: Date(),
            gameHistory: state.gameHistory
        )
        let dict = payload.toDictionary()
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(dict, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(dict)
            }
        } else {
            WCSession.default.transferUserInfo(dict)
        }
    }

    private func applyColors(aHex: String?, bHex: String?) {
        if let hex = aHex { teamAColor = Color(hex: hex) ?? .red }
        if let hex = bHex { teamBColor = Color(hex: hex) ?? .blue }
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }
        let aHex = context[WatchMessageKey.teamAColor] as? String
        let bHex = context[WatchMessageKey.teamBColor] as? String
        Task { @MainActor in applyColors(aHex: aHex, bHex: bHex) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let aHex = applicationContext[WatchMessageKey.teamAColor] as? String
        let bHex = applicationContext[WatchMessageKey.teamBColor] as? String
        Task { @MainActor in applyColors(aHex: aHex, bHex: bHex) }
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
