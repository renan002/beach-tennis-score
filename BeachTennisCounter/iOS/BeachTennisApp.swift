import SwiftUI
import SwiftData
import UIKit

@main
struct BeachTennisApp: App {
    @StateObject private var phoneSession: PhoneSessionManager
    private let container: ModelContainer
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

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
                .onAppear { applyTheme(appTheme) }
                .onChange(of: appTheme) { _, theme in applyTheme(theme) }
        }
        .modelContainer(container)
    }

    /// Applies the theme by overriding the interface style on the window itself
    /// rather than with `.preferredColorScheme`.
    ///
    /// `.preferredColorScheme(nil)` expresses *no preference* — it does not reset
    /// a style that a previous non-nil value already latched onto a presentation
    /// host. Selecting "system" after "light" or "dark" therefore left presented
    /// sheets stuck on the old style. Writing `.unspecified` clears the override
    /// explicitly, and because it is set on the window it cascades to sheets too.
    @MainActor
    private func applyTheme(_ theme: AppTheme) {
        let style = theme.interfaceStyle
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
