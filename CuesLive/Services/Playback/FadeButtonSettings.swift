import Foundation

/// How the setlist's Fade button fades: its length, and whether a low-pass sweep follows it.
/// Set from the button's right-click menu and remembered between launches.
enum FadeButtonSettings {
    static let durationKey = "fadeButtonSeconds"
    static let filterSweepKey = "fadeButtonFilterSweep"
    static let defaultDuration: TimeInterval = 5
    static let durationOptions: [TimeInterval] = [1, 2, 3, 5, 8, 10, 15, 20, 30]

    static var duration: TimeInterval {
        let stored = UserDefaults.standard.double(forKey: durationKey)
        return stored > 0 ? stored : defaultDuration
    }

    static func label(forSeconds seconds: TimeInterval) -> String {
        seconds == 1 ? "1 second" : "\(Int(seconds)) seconds"
    }

    /// On unless turned off.
    static var sweepsFilter: Bool {
        UserDefaults.standard.object(forKey: filterSweepKey) as? Bool ?? true
    }
}
