import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Cut, copy, paste and mute. Each acts on the time range when one is selected (on the selected
/// tracks), otherwise on the selected clips. All of them apply live while the song plays.
extension EditView {
    /// Put on the system pasteboard so Paste is offered, and checked so a paste only uses the
    /// editor's clips while they are still what was last copied.
    static let clipPasteboardMarker = "cues.live clips"

    private var activeRange: ClipRangeDrag? {
        guard let range = editSelection, range.end - range.start > ClipEditing.tolerance else { return nil }
        return range
    }

    var canCopyClips: Bool { activeRange != nil || !clipSelection.isEmpty }
    var canPasteClips: Bool { clipClipboard != nil }

    func copyClips() {
        if let range = activeRange {
            clipClipboard = ClipClipboard.copying(
                trackIDs: selectedTrackIDs,
                from: range.start,
                to: range.end,
                in: timeline.clips
            ) ?? clipClipboard
        } else {
            clipClipboard = ClipClipboard.copying(clipIDs: clipSelection.clipIDs, from: timeline.clips) ?? clipClipboard
        }
    }

    func cutClips() {
        if let range = activeRange {
            copyClips()
            let trackIDs = selectedTrackIDs
            commitTimelineEdit("Cut") { timeline in
                ClipEditing.deleteRange(trackIDs: trackIDs, from: range.start, to: range.end, in: &timeline.clips)
            }
            clipSelection.deselectAll()
        } else {
            guard !clipSelection.isEmpty else { return }
            copyClips()
            removeClipSelection()
        }
    }

    /// Pastes at the insertion point (or the start of the selected range), on the tracks the
    /// clips were copied from. The pasted clips end up selected.
    func pasteClips() {
        guard let board = clipClipboard?.keepingTracks(Set(song.sortedTracks.map(\.id))),
              !board.clips.isEmpty else { return }
        let time = playbackStart
        commitTimelineEdit("Paste") { timeline in
            clipSelection = ClipSelection(board.paste(at: time, into: &timeline.clips))
        }
        editSelection = nil
    }

    /// Mutes the selected range or clips; unmutes them when they are all muted already.
    func toggleMuteClips() {
        if let range = activeRange {
            let trackIDs = selectedTrackIDs
            commitTimelineEdit("Mute") { timeline in
                let inside = ClipEditing.toggleMute(trackIDs: trackIDs, from: range.start, to: range.end, in: &timeline.clips)
                clipSelection = ClipSelection(inside)
            }
        } else {
            let ids = clipSelection.clipIDs
            guard !ids.isEmpty else { return }
            commitTimelineEdit("Mute") { timeline in
                ClipEditing.toggleMute(clipIDs: ids, in: &timeline.clips)
            }
        }
    }

    #if os(macOS)
    /// Leaves a marker on the system pasteboard so Edit ▸ Paste is offered for clips.
    func clipPasteboardItems() -> [NSItemProvider] {
        copyClips()
        return clipClipboard == nil ? [] : [NSItemProvider(object: Self.clipPasteboardMarker as NSString)]
    }

    func clipPasteboardItemsCutting() -> [NSItemProvider] {
        let items = clipPasteboardItems()
        cutClips()
        return items
    }

    /// Pastes clips only while the system pasteboard still holds what the editor copied.
    func pasteClipsFromPasteboard() {
        guard NSPasteboard.general.string(forType: .string) == Self.clipPasteboardMarker else { return }
        pasteClips()
    }
    #endif
}
