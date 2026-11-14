import Foundation

/// Remembers the setlist's group fader levels for each song, so every song carries its own mix.
///
/// Levels are kept in `UserDefaults` by song ID rather than in the song file: they are a
/// setlist-side mix on top of the track levels set in the editor.
struct SongGroupMixStore {
    static let storageKey = "songGroupMixLevels"

    var defaults: UserDefaults = .standard

    /// The saved fader levels for `songID`, by group ID (`OutputRoutingStore.ungroupedRouteID`
    /// for No Group). `nil` when the song has no mix of its own yet.
    func levels(for songID: UUID) -> [UUID: Double]? {
        guard let stored = allLevels()[songID.uuidString] else { return nil }
        var levels: [UUID: Double] = [:]
        for (key, value) in stored {
            if let id = UUID(uuidString: key) {
                levels[id] = value
            }
        }
        return levels
    }

    func save(_ levels: [UUID: Double], for songID: UUID) {
        var all = allLevels()
        var stored: [String: Double] = [:]
        for (id, value) in levels {
            stored[id.uuidString] = value
        }
        all[songID.uuidString] = stored
        defaults.set(all, forKey: Self.storageKey)
    }

    private func allLevels() -> [String: [String: Double]] {
        defaults.dictionary(forKey: Self.storageKey) as? [String: [String: Double]] ?? [:]
    }
}
