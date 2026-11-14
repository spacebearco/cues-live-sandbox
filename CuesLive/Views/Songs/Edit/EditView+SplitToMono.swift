import SwiftUI

extension EditView {
    /// Splits a stereo track into left and right mono tracks, as one undo step. The engine
    /// reloads to pick up the new track, which stops playback.
    func splitTrackToMono(_ track: AudioTrack) {
        guard TrackChannelSplitter.canSplit(track, fileURL: FileStore.cachedTrackURL(for: song, track: track)) else {
            importError = "\u{201C}\(track.displayName)\u{201D} isn't a stereo file, so there is nothing to split."
            return
        }
        performUndoableChange("Split to Mono") {
            TrackChannelSplitter.split(track, in: song, timeline: &timeline, context: modelContext)
            try? modelContext.save()
            persistProjectState()
        }
        viewModel.reloadSongAfterMediaChange()
    }
}
