import SwiftData
import SwiftUI

/// Fade-in into a section, the standalone filter sweep, Me Time and the song-linked group faders.
extension LivePlaybackView {
    /// Moves playback to the run-up of the section a fade-in should land on (the cued section,
    /// or the one playing) and returns how long the fade-in has. `nil` fades in where the
    /// song is: the setting is off, the song has no tempo or sections, or there is no room.
    func enterSectionForFadeIn() -> TimeInterval? {
        guard coordinator.isLoaded, let snapshot = coordinator.currentWaveformSnapshot else { return nil }
        let now = coordinator.currentTime
        let section = snapshot.sections.first { $0.id == cuedSectionID }
            ?? snapshot.sections.section(atTimeline: now)
        guard let section, let entry = ShowJumpPlanner.sectionEntry(
            to: section.timelineStartSeconds,
            from: now,
            leadBars: FadeButtonSettings.entryBars,
            keepsBeatPhase: coordinator.isPlaying,
            tempoChanges: snapshot.tempoChanges,
            timeSignatureChanges: snapshot.timeSignatureChanges
        ) else { return nil }

        clearMarkerCue()
        sectionLoop.endLoopIfActive()
        coordinator.seek(to: entry.start)
        if !coordinator.isPlaying {
            coordinator.play()
        }
        return entry.duration
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
