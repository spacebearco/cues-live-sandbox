import SwiftUI

extension EditView {
    /// Snaps a drag of the selection to the nearest clip edge on any other track, the playhead,
    /// the insertion point, or a section marker. `nil` when nothing is close enough.
    func magneticSnap(edges: [TimeInterval], rawDelta: TimeInterval) -> ClipSnapping.Snap? {
        guard timelineDuration > 0, timelineContentWidth > 0 else { return nil }
        let pointsPerSecond = Double(timelineContentWidth) / timelineDuration
        let threshold = ClipSnapping.thresholdPoints / pointsPerSecond
        let targets = ClipSnapping.targets(
            clips: timeline.clips,
            excluding: clipSelection.clipIDs,
            extraTargets: [0, audioEngine.currentTime, insertionTime] + sectionMarkerTimes
        )
        return ClipSnapping.snap(edges: edges, rawDelta: rawDelta, targets: targets, threshold: threshold)
    }

    /// A line through every lane where the dragged edge has snapped.
    @ViewBuilder
    var snapGuideOverlay: some View {
        if clipDrag != nil, let time = snapGuideTime {
            let x = TimelineLayout.xPosition(
                for: time,
                duration: timelineDuration,
                contentWidth: timelineContentWidth
            )
            Rectangle()
                .fill(AppColors.accent)
                .frame(width: 1, height: trackAreaHeight)
                .offset(x: x)
                .frame(width: timelineContentWidth, height: trackAreaHeight, alignment: .topLeading)
                .allowsHitTesting(false)
        }
    }
}
