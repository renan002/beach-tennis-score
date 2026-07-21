// PROTOTYPE — throwaway. Lives on branch prototype/102-health-toggle only.
//
// QUESTION
// --------
// Issue #102's Health Monitoring toggle has two inputs that disagree with each
// other: the value the user stored on the phone (`healthMonitoringEnabled`) and
// the last-known HealthKit grant the watch reported (`HealthAuthStatus`). The
// design doc calls for a "display override, not overwrite": while denied, the
// row reads OFF and disabled, but the stored value is untouched so a re-grant
// auto-resumes the user's real choice.
//
// Does that two-input model actually hold up when you push it through the
// sequences a real user produces — toggle off, then deny; deny, then re-grant;
// never-reported status on a fresh install; deny while the row is already off?
// This module is the pure answer; main.swift is the throwaway shell that drives
// it. If the model survives, THIS FILE is what gets lifted into Shared/.
//
// Mirrors the real `HealthAuthStatus` from Shared/WorkoutPolicy.swift, redeclared
// here so the prototype compiles standalone with `swiftc`.

import Foundation

enum HealthAuthStatus: String, CaseIterable {
    case undetermined
    case granted
    case denied
}

/// Which footer copy the Health section shows. Keys, not display text — the
/// real view maps these onto String Catalog entries.
enum HealthFooter: String {
    case normal
    case denied
}

/// Everything the Health section needs to render, derived from the two inputs.
struct HealthToggleDisplay: Equatable {
    let isOn: Bool
    let isInteractive: Bool
    let footer: HealthFooter
}

/// The pure decision core for the phone-side Health section. No SwiftUI, no
/// UserDefaults — the view binds to this and nothing else.
enum HealthTogglePolicy {
    /// - Parameters:
    ///   - storedEnabled: the user's persisted choice. Never written by a denial.
    ///   - watchStatus: last status the watch pushed, or nil if it never has.
    static func display(storedEnabled: Bool, watchStatus: HealthAuthStatus?) -> HealthToggleDisplay {
        if watchStatus == .denied {
            // Display override: read off, refuse input, leave `storedEnabled` alone.
            return HealthToggleDisplay(isOn: false, isInteractive: false, footer: .denied)
        }
        return HealthToggleDisplay(isOn: storedEnabled, isInteractive: true, footer: .normal)
    }

    /// What the stored value becomes when the user taps the row. A tap on a
    /// non-interactive row is a no-op — the guarantee that makes "override, not
    /// overwrite" true rather than merely intended.
    static func toggled(storedEnabled: Bool, watchStatus: HealthAuthStatus?) -> Bool {
        guard display(storedEnabled: storedEnabled, watchStatus: watchStatus).isInteractive else {
            return storedEnabled
        }
        return !storedEnabled
    }

    /// Whether the watch would start a workout at the next Match start, given
    /// what the phone last synced. Mirrors `WorkoutPolicy.startDecision` — here
    /// only so the TUI can show the consequence of the toggle state.
    static func watchWouldStartWorkout(syncedEnabled: Bool, watchStatus: HealthAuthStatus?) -> Bool {
        guard syncedEnabled else { return false }
        return watchStatus != .denied
    }
}
