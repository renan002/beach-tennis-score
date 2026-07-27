import SwiftUI

@main
struct BeachTennisWatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager.shared
    @StateObject private var workoutManager = WorkoutManager.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(sessionManager)
                .environmentObject(workoutManager)
        }
    }
}
