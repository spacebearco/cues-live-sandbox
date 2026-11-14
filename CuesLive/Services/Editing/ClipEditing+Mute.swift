import Foundation

extension ClipEditing {
    /// Mutes the clips, or unmutes them when every one is already muted. Returns the new state.
    @discardableResult
    static func toggleMute(clipIDs: Set<UUID>, in clips: inout [TrackClip]) -> Bool {
        let targets = clips.filter { clipIDs.contains($0.id) }
        let mute = !targets.allSatisfy(\.isMuted)
        for index in clips.indices where clipIDs.contains(clips[index].id) {
            clips[index].isMuted = mute
        }
        return mute
    }

    /// Mutes (or, when it is all muted already, unmutes) exactly `[start, end)` on the given
    /// tracks: clips crossing an edge are split there first. Returns the clips inside the range.
    @discardableResult
    static func toggleMute(
        trackIDs: Set<UUID>,
        from start: TimeInterval,
        to end: TimeInterval,
        in clips: inout [TrackClip]
    ) -> Set<UUID> {
        let crossing = Set(clips.filter { clip in
            trackIDs.contains(clip.trackID)
                && clip.timelineStartSeconds < end - tolerance
                && clip.timelineEndSeconds > start + tolerance
        }.map(\.id))
        guard !crossing.isEmpty else { return [] }
        let pieces = crossing.union(split(clipIDs: crossing, at: [start, end], in: &clips))
        let inside = Set(clips.filter { clip in
            pieces.contains(clip.id)
                && clip.timelineStartSeconds >= start - tolerance
                && clip.timelineEndSeconds <= end + tolerance
        }.map(\.id))
        toggleMute(clipIDs: inside, in: &clips)
        return inside
    }
}
