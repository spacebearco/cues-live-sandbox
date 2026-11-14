import Foundation

/// Magnetic snapping for clip drags. When a dragged edge comes within `threshold` of a target
/// (another clip's edge, the playhead, a section marker), it jumps onto that target.
enum ClipSnapping {
    /// A snap that won: how far to move, and the target the edge landed on.
    struct Snap: Equatable {
        var delta: TimeInterval
        var target: TimeInterval
    }

    /// Distance, in screen points, inside which an edge is pulled onto a target.
    static let thresholdPoints: Double = 8

    /// Every clip edge outside `excluded`, plus `extraTargets`, sorted and without duplicates.
    static func targets(
        clips: [TrackClip],
        excluding excluded: Set<UUID>,
        extraTargets: [TimeInterval]
    ) -> [TimeInterval] {
        var times = extraTargets
        for clip in clips where !excluded.contains(clip.id) {
            times.append(clip.timelineStartSeconds)
            times.append(clip.timelineEndSeconds)
        }
        return Array(Set(times)).sorted()
    }

    /// The closest snap for a group of edges that all move by `rawDelta`, if any edge lands
    /// within `threshold` of a target.
    static func snap(
        edges: [TimeInterval],
        rawDelta: TimeInterval,
        targets: [TimeInterval],
        threshold: TimeInterval
    ) -> Snap? {
        var best: Snap?
        var bestDistance = threshold
        for edge in edges {
            let moved = edge + rawDelta
            for target in targets {
                let distance = abs(target - moved)
                guard distance <= bestDistance else { continue }
                bestDistance = distance
                best = Snap(delta: target - edge, target: target)
            }
        }
        return best
    }
}
