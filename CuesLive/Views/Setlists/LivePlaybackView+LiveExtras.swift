import SwiftData
import SwiftUI

/// Panic, the standalone filter sweep, Me Time and the song-linked group faders.
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
        let mainUID = OutputRoutingStore.config(in: modelContext).selectedDeviceUID
        let channelCount = AudioOutputDeviceService.channelCount(for: mainUID)
        let snapshot = OutputRoutingStore.snapshot(in: modelContext, channelCount: channelCount)
        guard isMeTimeOn, playMode == .edit else {
            // With no device selected the engine follows the system default, and would stay on
            // the Me Time device after a visit there. Name the default so it binds back.
            guard mainUID == nil, MeTimeSettings.usesAnotherDevice(mainDeviceUID: mainUID) else { return snapshot }
            return snapshot.onDevice(AudioOutputDeviceService.defaultOutputDeviceUID())
        }
        let output = MeTimeSettings.output(
            mainDeviceUID: mainUID,
            mainChannelCount: channelCount,
            devices: AudioOutputDeviceService.availableDevices()
        )
        return snapshot.routingEverything(to: output.destination, on: output.device)
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

    // MARK: - Song-linked faders

    /// A group fader wrote new gains to `song`'s tracks: play them and save the song.
    func applyTrackGains(of song: Song) {
        if coordinator.hasLoadedSong(song.id) {
            for track in song.sortedTracks {
                coordinator.playbackEngine.setTrackVolume(id: track.id, volume: Float(track.volume))
            }
        }
        try? SongProjectBridge.syncProjectFile(for: song, context: modelContext)
    }
}
