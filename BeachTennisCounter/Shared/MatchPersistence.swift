import Foundation

/// Persists the in-progress match so a watchOS app termination mid-match
/// doesn't lose the score. UserDefaults-backed; one match at a time.
enum MatchPersistence {
    static let key = "inProgressMatch"
    /// A saved match older than this is considered abandoned, not resumable.
    static let defaultMaxAge: TimeInterval = 12 * 60 * 60

    private struct Saved: Codable {
        var state: MatchState
        var savedAt: Date
    }

    static func save(
        _ state: MatchState,
        in defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        guard !state.isMatchOver else {
            clear(in: defaults)
            return
        }
        guard let data = try? JSONEncoder().encode(Saved(state: state, savedAt: now)) else { return }
        defaults.set(data, forKey: key)
    }

    static func load(
        in defaults: UserDefaults = .standard,
        now: Date = Date(),
        maxAge: TimeInterval = defaultMaxAge
    ) -> MatchState? {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(Saved.self, from: data),
              !saved.state.isMatchOver,
              now.timeIntervalSince(saved.savedAt) <= maxAge
        else { return nil }
        return saved.state
    }

    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
