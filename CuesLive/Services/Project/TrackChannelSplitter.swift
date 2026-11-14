import AVFoundation
import SwiftData

/// Split to Mono: a stereo track becomes two mono tracks on the same file, the original playing
/// the left channel (panned left) and a new track right after it playing the right channel
/// (panned right). Mix, group, trims and every clip are copied. No audio is rewritten.
enum TrackChannelSplitter {
    /// True for a track that still plays a two-channel file as recorded.
    static func canSplit(_ track: AudioTrack, fileURL: URL?) -> Bool {
        guard track.sourceChannel == nil, let fileURL,
              let file = try? AVAudioFile(forReading: fileURL) else { return false }
        return file.fileFormat.channelCount == 2
    }

    /// Splits `track` and returns the new right-channel track. Its clips are added to `timeline`.
    @discardableResult
    static func split(
        _ track: AudioTrack,
        in song: Song,
        timeline: inout SongTimeline,
        context: ModelContext
    ) -> AudioTrack {
        let baseName = track.displayName
        for other in song.tracks where other.sortOrder > track.sortOrder {
            other.sortOrder += 1
        }

        let right = AudioTrack(
            displayName: "\(baseName) R",
            relativeFilePath: track.relativeFilePath,
            sortOrder: track.sortOrder + 1
        )
        right.mediaPath = track.mediaPath
        right.mediaPathStyleRaw = track.mediaPathStyleRaw
        right.mediaBookmarkData = track.mediaBookmarkData
        right.volume = track.volume
        right.isMuted = track.isMuted
        right.isSolo = track.isSolo
        right.trimStartSeconds = track.trimStartSeconds
        right.trimEndSeconds = track.trimEndSeconds
        right.includeInKeyChange = track.includeInKeyChange
        right.sourceDurationSeconds = track.sourceDurationSeconds
        right.laneHeight = track.laneHeight
        right.group = track.group
        right.sourceChannel = 1
        right.pan = 1
        right.song = song
        context.insert(right)
        song.tracks.append(right)

        track.displayName = "\(baseName) L"
        track.sourceChannel = 0
        track.pan = -1

        let copies = timeline.clips.filter { $0.trackID == track.id }.map { clip in
            TrackClip(
                trackID: right.id,
                timelineStartSeconds: clip.timelineStartSeconds,
                duration: clip.duration,
                sourceStartSeconds: clip.sourceStartSeconds,
                gainDB: clip.gainDB,
                playbackRate: clip.playbackRate,
                fadeIn: clip.fadeIn,
                fadeOut: clip.fadeOut,
                isMuted: clip.isMuted
            )
        }
        timeline.clips.append(contentsOf: copies)
        ClipEditing.sort(&timeline.clips)
        return right
    }
}
