import SwiftUI
import SwiftData

@main
struct BeachTennisApp: App {
    @StateObject private var phoneSession: PhoneSessionManager
    private let container: ModelContainer
    @AppStorage("appTheme") private var appTheme: String = "system"

    init() {
        let c = Self.makeContainer()
        container = c
        let session = PhoneSessionManager.shared
        session.setModelContainer(c)
        _phoneSession = StateObject(wrappedValue: session)
    }

    private static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: StoredMatch.self)
        } catch {
            // Store is unreadable (e.g. schema migration failed). Move the SQLite
            // files aside as a recoverable backup and start fresh.
            StoreRecovery.moveStoreAside(in: .applicationSupportDirectory)
            do {
                return try ModelContainer(for: StoredMatch.self)
            } catch {
                fatalError("ModelContainer unrecoverable: \(error)")
            }
        }
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
