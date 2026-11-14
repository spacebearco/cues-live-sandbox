import SwiftUI

/// Clicks on the playing song's waveform. Show mode cues the clicked section, firing at the end
/// of the current section, the next bar or the next beat (the toolbar's Jump setting); Edit
/// mode moves the playhead right where you click.
extension LivePlaybackView {
    /// Stands in for a section when a bar or beat jump lands outside every section, so the cue
    /// monitor still fires.
    static let gridJumpCueID = UUID()

    func handleWaveformClick(at time: TimeInterval) {
        guard let snapshot = coordinator.currentWaveformSnapshot else {
            coordinator.seek(to: time)
            return
        }
        switch playMode {
        case .edit:
            clearMarkerCue()
            sectionLoop.endLoopIfActive()
            coordinator.seek(to: time)
        case .show:
            showModeClick(at: time, in: snapshot)
        }
    }

    /// A click on a section cues that section; the Jump setting decides when it fires. A song
    /// without sections jumps to the clicked bar or beat line instead.
    private func showModeClick(at time: TimeInterval, in snapshot: LiveSongWaveformSnapshot) {
        if let section = snapshot.sections.section(atTimeline: time) {
            cueSection(section)
            return
        }

        guard showQuantize != .section, coordinator.isPlaying else {
            clearMarkerCue()
            coordinator.seek(to: ShowJumpPlanner.gridStart(
                containing: time,
                quantize: showQuantize,
                tempoChanges: snapshot.tempoChanges,
                timeSignatureChanges: snapshot.timeSignatureChanges
            ))
            return
        }
        guard let jump = ShowJumpPlanner.plan(
            clickedTime: time,
            now: coordinator.currentTime,
            quantize: showQuantize,
            tempoChanges: snapshot.tempoChanges,
            timeSignatureChanges: snapshot.timeSignatureChanges
        ) else { return }

        sectionLoop.endLoopIfActive()
        clearMarkerCue()
        cuedSectionID = snapshot.sections.section(atTimeline: jump.target)?.id ?? Self.gridJumpCueID
        cueTargetTime = jump.target
        cueFireTime = jump.fireTime
        coordinator.scheduleSectionTransition(to: jump.target, at: jump.fireTime)
    }
}
