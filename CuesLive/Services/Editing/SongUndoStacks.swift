import Foundation

/// One undo stack per song, shared by the setlist's editor window and the setlist faders, so
/// a fader move made while the song plays can be undone in the editor.
///
/// The stack outlives any one editor window. The window clears it when it closes, because the
/// steps it recorded restore state through that window's views.
@MainActor
enum SongUndoStacks {
    private static var controllers: [UUID: SongUndoController] = [:]

    static func controller(for songID: UUID) -> SongUndoController {
        if let controller = controllers[songID] {
            return controller
        }
        let controller = SongUndoController()
        controllers[songID] = controller
        return controller
    }

    /// Records a change to some of a song's track gains. Undo and redo write the gains back
    /// and hand the song to `apply` so playback and the project file follow.
    static func registerTrackGainChange(
        _ actionName: String,
        song: Song,
        before: [UUID: Double],
        after: [UUID: Double],
        apply: @escaping (Song) -> Void
    ) {
        controller(for: song.id).registerChange(actionName: actionName, before: before, after: after) { gains in
            for track in song.sortedTracks {
                if let volume = gains[track.id] {
                    track.volume = volume
                }
            }
            apply(song)
        }
    }

    static func clear(for songID: UUID) {
        controllers[songID]?.removeAllActions()
    }
}
