import Foundation

/// Track and group mix: volume, pan, mute/solo, group faders and meters.
extension AudioEngineManager {
    /// Audible-only volume/pan update for dragging a fader: skips the duration and
    /// mapper refresh that `updateTrackSettings` does.
    func applyLiveTrackMix(id: UUID, volume: Float, pan: Float) {
        guard var track = tracks[id] else { return }
        track.settings.volume = volume
        track.settings.pan = pan
        tracks[id] = track
        applyAllMixSettings()
    }

    func applyGroupMix(_ snapshot: GroupMixSnapshot) {
        groupMixSnapshot = snapshot
        applyAllMixSettings()
    }

    func updateTrackGroup(id: UUID, groupID: UUID?) {
        guard var track = tracks[id] else { return }
        track.groupID = groupID
        tracks[id] = track
        refreshMixMeterMeasuredTracks()
    }

    func applyProvisionalGroupVolume(groupID: UUID?, volume: Float) {
        applyGroupMix(groupMixSnapshot.replacingVolume(groupID: groupID, volume: volume))
    }

    /// A track's smoothed RMS (linear), beside its peak in `trackMeterLevels`.
    func trackRMSLevel(id: UUID) -> Float {
        tracks[id]?.memoryPlayer.rmsLevel() ?? 0
    }

    func groupMeterLevel(for groupID: UUID?) -> Float {
        let key = groupID ?? OutputRoutingStore.ungroupedRouteID
        return groupMeterLevels[key] ?? 0
    }

    func applyAllMixSettings() {
        let anySolo = tracks.values.contains { $0.settings.isSolo }
        let snapshot = groupMixSnapshot

        for id in tracks.keys {
            guard let track = tracks[id] else { continue }
            var effectiveVolume = track.settings.volume
            var isAudible = true

            if anySolo {
                if !track.settings.isSolo, !track.settings.ignoresSolo {
                    effectiveVolume = 0
                    isAudible = false
                }
            } else if track.settings.isMuted {
                effectiveVolume = 0
                isAudible = false
            }

            let groupVolume: Float
            let groupMuted: Bool
            if let groupID = track.groupID {
                groupVolume = snapshot.volumeByGroupID[groupID] ?? 1
                groupMuted = snapshot.mutedGroupIDs.contains(groupID)
            } else {
                groupVolume = snapshot.ungroupedVolume
                groupMuted = snapshot.ungroupedIsMuted
            }
            effectiveVolume *= groupMuted ? 0 : groupVolume

            track.memoryPlayer.updateMix(
                volume: effectiveVolume,
                pan: track.settings.pan,
                isAudible: isAudible
            )
            track.memoryPlayer.setLowPassClosure(snapshot.fadeFilter.closure(forGroup: track.groupID))
        }
        applyAnnouncementGain()
    }
}
