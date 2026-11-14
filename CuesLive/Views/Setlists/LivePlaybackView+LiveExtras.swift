import SwiftData
import SwiftUI

/// Panic, the standalone filter sweep, Me Time and the per-song fader mix.
extension LivePlaybackView {
    /// Jumps to one bar before the start of the section playing and keeps (or starts) playback,
    /// so the band gets a bar of pre-roll back into the section.
    func panicToSectionStart() {
        guard coordinator.isLoaded else { return }
        let snapshot = coordinator.currentWaveformSnapshot
        let target = ShowJumpPlanner.panicTarget(
            now: coordinator.currentTime,
            sections: snapshot?.sections ?? [],
            tempoChanges: snapshot?.tempoChanges ?? [],
            timeSignatureChanges: snapshot?.timeSignatureChanges ?? []
        )
        clearMarkerCue()
        sectionLoop.endLoopIfActive()
        coordinator.seek(to: target)
        if !coordinator.isPlaying {
            coordinator.play()
        }
    }

    func toggleFilterSweep() {
        groupMixFade.toggleFilterSweep(context: modelContext, duration: coordinator.fadeButtonDuration) {
            coordinator.updateGroupMix(context: modelContext, persist: false)
        }
    }

    // MARK: - Me Time

    /// The saved routing, or everything on the Me Time output while Me Time is on.
    func liveRoutingSnapshot() -> OutputRoutingSnapshot {
        let channelCount = AudioOutputDeviceService.channelCount(
            for: OutputRoutingStore.config(in: modelContext).selectedDeviceUID
        )
        let snapshot = OutputRoutingStore.snapshot(in: modelContext, channelCount: channelCount)
        guard isMeTimeOn, playMode == .edit else { return snapshot }
        return snapshot.routingEverything(to: MeTimeSettings.destination(channelCount: channelCount))
    }

    func toggleMeTime() {
        isMeTimeOn.toggle()
        coordinator.applyOutputRouting()
    }

    func endMeTime() {
        guard isMeTimeOn else { return }
        isMeTimeOn = false
        coordinator.applyOutputRouting()
    }

    // MARK: - Per-song fader mix

    /// Remembers the faders for the song being left and sets them for the one arriving. A song
    /// without a mix of its own keeps the levels that are up. Skipped mid-fade, when the
    /// faders hold the fade's levels rather than the mix.
    func switchSongMix(from oldSongID: UUID?, to newSongID: UUID?) {
        guard !groupMixFade.isFadedOut, !groupMixFade.isFading else { return }
        let store = SongGroupMixStore()
        if let oldSongID {
            store.save(currentFaderLevels(), for: oldSongID)
        }
        guard let newSongID, let levels = store.levels(for: newSongID) else { return }
        for group in mixableGroups() {
            if let level = levels[group.id] {
                group.volume = level
            }
        }
        if let level = levels[OutputRoutingStore.ungroupedRouteID] {
            OutputRoutingStore.config(in: modelContext).ungroupedVolume = level
        }
        coordinator.updateGroupMix(context: modelContext)
    }

    /// Saves the faders as the playing song's mix, after a fader or mute change.
    func saveCurrentSongMix() {
        guard !groupMixFade.isFadedOut, !groupMixFade.isFading,
              let songID = coordinator.currentSong?.id else { return }
        SongGroupMixStore().save(currentFaderLevels(), for: songID)
    }

    private func currentFaderLevels() -> [UUID: Double] {
        var levels: [UUID: Double] = [:]
        for group in mixableGroups() {
            levels[group.id] = group.volume
        }
        levels[OutputRoutingStore.ungroupedRouteID] = OutputRoutingStore.config(in: modelContext).ungroupedVolume
        return levels
    }

    private func mixableGroups() -> [TrackGroup] {
        TrackGroupStore.sortedGroups(from: modelContext).filter { !TimecodePlaybackSupport.isTimecodeGroup($0) }
    }
}
