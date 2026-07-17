import SwiftUI
import SwiftData

@main
struct BeachTennisApp: App {
    @StateObject private var phoneSession: PhoneSessionManager
    private let container: ModelContainer
    @AppStorage("appTheme") private var appTheme: String = "system"

    init() {
        let c = LiveStore.open(in: LiveStore.directory)
        container = c
        let session = PhoneSessionManager.shared
        session.setModelContainer(c)
        _phoneSession = StateObject(wrappedValue: session)
    }

    var body: some Scene {
        WindowGroup {
            MatchListView()
                .environmentObject(phoneSession)
                .preferredColorScheme(appTheme == "light" ? .light : appTheme == "dark" ? .dark : nil)
        }
        .modelContainer(container)
    }
}
