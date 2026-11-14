import SwiftUI

/// Group faders that follow the playing song's track gains (`GroupFaderLink`).
extension LiveGroupMixerView {
    /// The playing song's tracks in `group` (`nil` for No Group).
    func linkedTracks(in group: TrackGroup?) -> [AudioTrack] {
        guard let song else { return [] }
        return song.sortedTracks.filter { $0.group?.id == group?.id }
    }

    /// The fader's value: linked to the song's tracks in the group when it has any, otherwise
    /// the group's own level.
    func faderLevel(groupVolume: Binding<Double>, tracks: [AudioTrack]) -> Binding<Double> {
        guard !tracks.isEmpty else { return groupVolume }
        return Binding(
            get: {
                GroupFaderLink.level(groupVolume: groupVolume.wrappedValue, trackVolumes: tracks.map(\.volume))
            },
            set: { newLevel in
                let scaled = GroupFaderLink.trackVolumes(
                    scaling: tracks.map(\.volume),
                    groupVolume: groupVolume.wrappedValue,
                    toLevel: newLevel
                )
                for (track, volume) in zip(tracks, scaled) {
                    track.volume = volume
                }
            }
        )
    }

    /// While a linked fader is dragged the engine hears it as a group level, scaled so the
    /// sound matches where the thumb is; the track gains are written when the drag ends.
    func liveVolumeChange(groupID: UUID?, tracks: [AudioTrack]) -> (UUID?, Double) -> Void {
        guard let loudest = tracks.map(\.volume).max() else { return onLiveVolumeChange }
        return { _, level in
            guard loudest > 0 else { return }
            onLiveVolumeChange(groupID, level / loudest)
        }
    }

    func mixChange(tracks: [AudioTrack]) -> () -> Void {
        guard let song, !tracks.isEmpty else { return onMixChange }
        return {
            onTrackGainsChanged(song)
            onMixChange()
        }
    }
}
