// PROTOTYPE — throwaway TUI shell over HealthToggleDisplay.swift.
// Run: BeachTennisCounter/Prototypes/HealthToggle/run.sh

import Foundation

// MARK: - In-memory world

var storedEnabled = true          // the phone's persisted setting
var syncedEnabled = true          // what the watch last received (pushed on Done)
var watchStatus: HealthAuthStatus?  // nil = the watch has never reported
var lastAction = "started"

// MARK: - Rendering

let bold = "\u{1b}[1m", dim = "\u{1b}[2m", reset = "\u{1b}[0m"
let green = "\u{1b}[32m", red = "\u{1b}[31m", yellow = "\u{1b}[33m"

func statusLabel(_ s: HealthAuthStatus?) -> String {
    guard let s else { return "\(dim)never reported\(reset)" }
    switch s {
    case .granted:      return "\(green)granted\(reset)"
    case .denied:       return "\(red)denied\(reset)"
    case .undetermined: return "\(yellow)undetermined\(reset)"
    }
}

func render() {
    let d = HealthTogglePolicy.display(storedEnabled: storedEnabled, watchStatus: watchStatus)
    let willStart = HealthTogglePolicy.watchWouldStartWorkout(syncedEnabled: syncedEnabled,
                                                             watchStatus: watchStatus)
    print("\u{1b}[2J\u{1b}[H", terminator: "")
    print("\(bold)#102 — Health Monitoring toggle\(reset)  \(dim)display override, not overwrite\(reset)")
    print(String(repeating: "─", count: 62))
    print("\(bold)INPUTS\(reset)")
    print("  stored (phone)      \(storedEnabled ? "on" : "off")")
    print("  synced (to watch)   \(syncedEnabled ? "on" : "off")\(storedEnabled == syncedEnabled ? "" : "   \(yellow)← unsynced\(reset)")")
    print("  watch auth status   \(statusLabel(watchStatus))")
    print("")
    print("\(bold)SETTINGS SECTION RENDERS\(reset)")
    print("  Health Monitoring   [\(d.isOn ? " ON" : "OFF")]\(d.isInteractive ? "" : "  \(dim)(disabled)\(reset)")")
    print("  footer              \(d.footer.rawValue)")
    print("    \(dim)\(d.footer == .denied ? "Health access was denied on the Watch. To re-enable it, open Settings › Privacy & Security › Health." : "The Watch records each match as a workout with live heart rate.")\(reset)")
    print("")
    print("\(bold)CONSEQUENCE — next Match start on the watch\(reset)")
    print("  \(willStart ? "\(green)starts a workout\(reset)" : "\(red)no workout, no auth prompt\(reset)")")
    print("")
    print("\(dim)last: \(lastAction)\(reset)")
    print(String(repeating: "─", count: 62))
    print("\(bold)[t]\(reset) tap toggle  \(bold)[s]\(reset) sync to watch (Done)  \(bold)[g]\(reset)ranted  \(bold)[d]\(reset)enied")
    print("\(bold)[u]\(reset)ndetermined  \(bold)[n]\(reset) never reported  \(bold)[r]\(reset) reset  \(bold)[q]\(reset) quit")
}

// MARK: - Raw-mode single keystroke

var original = termios()
tcgetattr(STDIN_FILENO, &original)
var raw = original
raw.c_lflag &= ~UInt(ECHO | ICANON)
tcsetattr(STDIN_FILENO, TCSANOW, &raw)
defer { tcsetattr(STDIN_FILENO, TCSANOW, &original) }

func readKey() -> Character? {
    var c: UInt8 = 0
    return read(STDIN_FILENO, &c, 1) == 1 ? Character(UnicodeScalar(c)) : nil
}

// MARK: - Loop

render()
loop: while let key = readKey() {
    switch key {
    case "t":
        let before = storedEnabled
        storedEnabled = HealthTogglePolicy.toggled(storedEnabled: storedEnabled, watchStatus: watchStatus)
        lastAction = before == storedEnabled
            ? "tapped toggle — ignored (row is not interactive)"
            : "tapped toggle — stored is now \(storedEnabled ? "on" : "off")"
    case "s":
        syncedEnabled = storedEnabled
        lastAction = "pushed settings to watch (synced = \(syncedEnabled ? "on" : "off"))"
    case "g": watchStatus = .granted;      lastAction = "watch reported granted"
    case "d": watchStatus = .denied;       lastAction = "watch reported denied"
    case "u": watchStatus = .undetermined; lastAction = "watch reported undetermined"
    case "n": watchStatus = nil;           lastAction = "watch has never reported (fresh install)"
    case "r":
        storedEnabled = true; syncedEnabled = true; watchStatus = nil
        lastAction = "reset to fresh install"
    case "q": break loop
    default: continue
    }
    render()
}
print("")
