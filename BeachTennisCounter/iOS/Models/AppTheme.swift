import SwiftUI
import UIKit

/// The `@AppStorage("appTheme")` setting. Raw values are persisted in `UserDefaults`
/// on real devices and must stay exactly `system` / `light` / `dark` — changing them
/// silently resets everyone to the default. They are storage keys, not display text,
/// and must never be localized.
enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    /// The `UIUserInterfaceStyle` to apply for this theme.
    ///
    /// `.unspecified` is used for `.system` rather than leaving the interface style
    /// untouched — see the comment on `applyTheme` in `BeachTennisApp.swift` for why
    /// `.preferredColorScheme(nil)` cannot be used instead.
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var displayName: LocalizedStringKey {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}
