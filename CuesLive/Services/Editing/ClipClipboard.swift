import Foundation

/// Clips copied in the editor, ready to paste. Times are measured from the start of what was
/// copied, and each clip remembers its track, so a paste lands on the tracks it came from.
struct ClipClipboard: Equatable {
    private(set) var clips: [TrackClip]
    /// Length of what was copied: a range keeps its full length even where it held gaps.
    let span: TimeInterval

    /// The selected clips, whole.
    static func copying(clipIDs: Set<UUID>, from clips: [TrackClip]) -> ClipClipboard? {
        let selected = clips.filter { clipIDs.contains($0.id) }
        guard let start = selected.map(\.timelineStartSeconds).min(),
              let end = selected.map(\.timelineEndSeconds).max() else { return nil }
        return ClipClipboard(clips: selected.map { relative($0, to: start) }, span: end - start)
    }

    /// Exactly `[start, end)` on the given tracks: clips crossing an edge are copied in part.
    static func copying(
        trackIDs: Set<UUID>,
        from start: TimeInterval,
        to end: TimeInterval,
        in clips: [TrackClip]
    ) -> ClipClipboard? {
        guard end - start >= TrackClip.minimumDuration else { return nil }
        let parts: [TrackClip] = clips.compactMap { clip in
            guard trackIDs.contains(clip.trackID) else { return nil }
            let lower = max(start, clip.timelineStartSeconds)
            let upper = min(end, clip.timelineEndSeconds)
            guard upper - lower >= TrackClip.minimumDuration else { return nil }
            var part = clip
            part.sourceStartSeconds = clip.sourceTime(atTimeline: lower)
            part.timelineStartSeconds = lower
            part.duration = upper - lower
            return relative(part, to: start)
        }
        guard !parts.isEmpty else { return nil }
        return ClipClipboard(clips: parts, span: end - start)
    }

    /// Pastes at `time` with fresh IDs. Pasted clips win over what they land on. Returns the
    /// pasted clips' IDs.
    func paste(at time: TimeInterval, into clips: inout [TrackClip]) -> Set<UUID> {
        let origin = max(0, time)
        let pasted = self.clips.map { clip in
            TrackClip(
                trackID: clip.trackID,
                timelineStartSeconds: origin + clip.timelineStartSeconds,
                duration: clip.duration,
                sourceStartSeconds: clip.sourceStartSeconds,
                gainDB: clip.gainDB,
                playbackRate: clip.playbackRate,
                fadeIn: clip.fadeIn,
                fadeOut: clip.fadeOut,
                isMuted: clip.isMuted
            )
        }
        ClipEditing.place(pasted, in: &clips)
        return Set(pasted.map(\.id))
    }

    /// Keeps only clips whose track still exists, for a paste into a song that lost tracks.
    func keepingTracks(_ trackIDs: Set<UUID>) -> ClipClipboard {
        ClipClipboard(clips: clips.filter { trackIDs.contains($0.trackID) }, span: span)
    }

    private static func relative(_ clip: TrackClip, to start: TimeInterval) -> TrackClip {
        var shifted = clip
        shifted.timelineStartSeconds -= start
        return shifted
    }
}
