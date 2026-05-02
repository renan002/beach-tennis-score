import SwiftUI

@main
struct BeachTennisWatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(sessionManager)
        }
    }
}
