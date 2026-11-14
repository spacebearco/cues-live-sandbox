import SwiftUI

/// The edit head (`insertionTime`) and the playhead are separate. A click moves only the edit
/// head, even mid-song. Split, Paste, Insert Bars and Play work from the edit head; Option-Command-T
/// cuts at the playhead instead. Return brings the edit head to the playhead, and Shift-Return
/// sends playback to the edit head.
extension EditView {
    /// Hidden while a time range is selected: the range shows where edits land.
    var editHeadTime: TimeInterval? {
        if let selection = editSelection, selection.end - selection.start > ClipEditing.tolerance {
            return nil
        }
        return insertionTime
    }

    var canSplitAtHeads: Bool {
        !clipSelection.isEmpty || !selectedTrackIDs.isEmpty
    }

    /// Splits at the edit head (or both edges of a selected range).
    func splitAtEditHead() {
        splitClips(clipsToSplit(at: editSplitPoints), at: editSplitPoints)
    }

    /// Splits at the playhead, wherever the edit head is.
    func splitAtPlayhead() {
        let time = audioEngine.currentTime
        splitClips(clipsToSplit(at: [time]), at: [time])
    }

    /// The selected clips, plus any clip on a selected track that a cut runs through.
    private func clipsToSplit(at times: [TimeInterval]) -> Set<UUID> {
        var ids = clipSelection.clipIDs
        for clip in timeline.clips
        where selectedTrackIDs.contains(clip.trackID) && times.contains(where: clip.containsTimelineTime) {
            ids.insert(clip.id)
        }
        return ids
    }

    func moveEditHeadToPlayhead() {
        editSelection = nil
        insertionTime = max(0, audioEngine.currentTime)
    }

    /// While playing, playback jumps to the edit head. Stopped, Play already starts there.
    func movePlayheadToEditHead() {
        guard audioEngine.isPlaying else { return }
        viewModel.seekAndPlay(to: playbackStart)
    }

    func handleEditHeadKey(_ press: KeyPress) -> KeyPress.Result {
        guard isTimelineFocused, !Self.isTypingText, press.key == .return,
              !press.modifiers.contains(.command), !press.modifiers.contains(.option) else { return .ignored }
        if press.modifiers.contains(.shift) {
            movePlayheadToEditHead()
        } else {
            moveEditHeadToPlayhead()
        }
        return .handled
    }

    /// A text field has the keyboard (a typed gain or pan, a rename). Return and the arrows
    /// belong to it then, not to the editor.
    static var isTypingText: Bool {
        #if os(macOS)
        KeyboardInputMonitor.isTextInputFocused
        #else
        false
        #endif
    }
}
