import SwiftData
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

extension EditView {
    var clipEditorActions: ClipEditorActions {
        ClipEditorActions(
            canSplit: canSplitAtHeads,
            canJoin: !clipSelection.isEmpty,
            canDuplicate: !clipSelection.isEmpty,
            canDeselect: !clipSelection.isEmpty,
            canAdjustGain: !clipSelection.isEmpty,
            canNudgeGain: !clipSelection.isEmpty,
            canInsertBars: true,
            canCopy: canCopyClips,
            canPaste: canPasteClips,
            split: { splitAtEditHead() },
            splitAtPlayhead: { splitAtPlayhead() },
            join: { joinSelectedClips() },
            duplicate: { duplicateSelectedClips() },
            deselectAll: { clipSelection.deselectAll() },
            adjustGain: { beginAdjustGain() },
            nudgeGainUp: { nudgeSelectedClipGain(by: 1) },
            nudgeGainDown: { nudgeSelectedClipGain(by: -1) },
            insertBars: { beginInsertBars(at: playbackStart) },
            toggleMute: { toggleMuteClips() }
        )
    }

    /// Delete clears the edit selection's range on the rows it covers. Without a range, it removes
    /// the selected clips whole.
    func removeClipSelection() {
        if let selection = editSelection, selection.end - selection.start > ClipEditing.tolerance {
            removeRange(selection)
            return
        }
        guard !clipSelection.isEmpty else { return }
        let ids = clipSelection.clipIDs
        commitTimelineEdit("Delete Clips") { timeline in
            ClipEditing.delete(clipIDs: ids, in: &timeline.clips)
        }
        clipSelection.deselectAll()
        clearMarkerCue(cancellingScheduledTransition: false)
    }

    /// Cuts `[start, end)` out of the clips on the selection's rows. Clips that span an edge keep
    /// the part outside the range; nothing shifts. The range stays selected.
    private func removeRange(_ selection: ClipRangeDrag) {
        let ids = displayedTrackIDs
        let firstRow = max(selection.firstRow, 0)
        let lastRow = min(selection.lastRow, ids.count - 1)
        guard firstRow <= lastRow else { return }
        let trackIDs = Set(ids[firstRow...lastRow])
        var edited = timeline.clips
        ClipEditing.deleteRange(trackIDs: trackIDs, from: selection.start, to: selection.end, in: &edited)
        clipSelection.deselectAll()
        guard edited != timeline.clips else { return }
        commitTimelineEdit("Delete Range") { timeline in
            timeline.clips = edited
        }
        clearMarkerCue(cancellingScheduledTransition: false)
    }


    func selectAllClips() {
        clipSelection = ClipSelection(timeline.clips.map(\.id))
    }

    /// Splits every selected clip that spans `time`; both halves stay selected.
    private func splitSelectedClips(at time: TimeInterval) {
        splitClips(clipSelection.clipIDs, at: [time])
    }

    /// Where Split cuts. A range is cut at both edges. An insertion is one cut.
    var editSplitPoints: [TimeInterval] {
        if let selection = editSelection, selection.end - selection.start > ClipEditing.tolerance {
            return [selection.start, selection.end]
        }
        return [insertionTime]
    }

    /// Split from the clip menu, at the edit selection.
    /// A clip already in the selection splits with every other selected clip, and with every clip
    /// on a selected track that the cut runs through. Any other clip splits alone.
    private func splitAtEditSelection(clickedClipID: UUID, clipWasSelected: Bool) {
        if !clipWasSelected {
            clipSelection = ClipSelection([clickedClipID])
        }
        var ids = clipSelection.clipIDs
        if clipWasSelected {
            for clip in timeline.clips where selectedTrackIDs.contains(clip.trackID) && editSplitPoints.contains(where: clip.containsTimelineTime) {
                ids.insert(clip.id)
            }
        }
        splitClips(ids, at: editSplitPoints)
    }

    /// Splits `ids` at each time. Pieces from an earlier cut are included in the later ones.
    func splitClips(_ ids: Set<UUID>, at times: [TimeInterval]) {
        let canSplit = timeline.clips.contains { clip in
            guard ids.contains(clip.id) else { return false }
            return times.contains { time in
                time - clip.timelineStartSeconds >= TrackClip.minimumDuration
                    && clip.timelineEndSeconds - time >= TrackClip.minimumDuration
            }
        }
        guard canSplit else { return }
        commitTimelineEdit("Split Clips") { timeline in
            let rightIDs = ClipEditing.split(clipIDs: ids, at: times, in: &timeline.clips)
            clipSelection.select(rightIDs)
        }
    }

    private func joinSelectedClips() {
        var joined = timeline.clips
        let remaining = ClipEditing.join(clipIDs: clipSelection.clipIDs, in: &joined)
        guard joined != timeline.clips else { return }
        commitTimelineEdit("Join Clips") { timeline in
            timeline.clips = joined
        }
        clipSelection = ClipSelection(remaining)
    }

    private func duplicateSelectedClips() {
        guard !clipSelection.isEmpty else { return }
        let ids = clipSelection.clipIDs
        commitTimelineEdit("Duplicate Clips") { timeline in
            clipSelection = ClipSelection(ClipEditing.duplicate(clipIDs: ids, in: &timeline.clips))
        }
    }

    private var selectedClips: [TrackClip] {
        timeline.clips.filter { clipSelection.contains($0.id) }
    }

    private func snappedToBeat(_ time: TimeInterval) -> TimeInterval {
        MeasureTiming.snapToNearestBeat(
            max(0, time),
            tempoChanges: normalizedTempoChanges,
            timeSignatureChanges: normalizedTimeSignatureChanges
        )
    }

    var clipLaneActions: ClipLaneActions {
        ClipLaneActions(
            press: { clipID, trackID, modifiers in
                let wasSelected = clipSelection.press(clipID, extending: modifiers.shift)
                pendingShiftDeselectID = wasSelected ? clipID : nil
            },
            click: { clipID, modifiers, time in
                // A click is an insertion, so the range selection does not stay underneath it.
                editSelection = nil
                if modifiers.option {
                    splitSelectedClips(at: time)
                } else {
                    clipSelection.click(
                        clipID,
                        extending: modifiers.shift,
                        removing: pendingShiftDeselectID == clipID
                    )
                }
                pendingShiftDeselectID = nil
            },
            drag: updateClipDrag,
            endDrag: commitClipDrag,
            marquee: updateRangeDrag,
            endMarquee: {
                // Mouse-up keeps editSelection. The range stays in place.
            },
            clickBlank: { trackID, time in
                editSelection = nil
                clipSelection.deselectAll()
                placeInsertion(on: trackID, at: time)
            },
            locate: { trackID, time in
                placeInsertion(on: trackID, at: time)
            },
            menu: performClipMenuAction
        )
    }

    /// Raises or lowers every selected clip by `delta` decibels.
    private func nudgeSelectedClipGain(by delta: Double) {
        let ids = clipSelection.clipIDs
        guard !ids.isEmpty else { return }
        var edited = timeline.clips
        ClipEditing.nudgeGain(clipIDs: ids, by: delta, in: &edited)
        guard edited != timeline.clips else { return }
        commitTimelineEdit(delta > 0 ? "Nudge Clip Gain Up" : "Nudge Clip Gain Down") { timeline in
            timeline.clips = edited
        }
    }

    /// Opens the gain prompt for the current selection. Mixed gains start with an empty field.
    private func beginAdjustGain() {
        let clips = selectedClips
        guard let first = clips.first else { return }
        let shared = clips.allSatisfy { abs($0.gainDB - first.gainDB) < 0.05 } ? first.gainDB : nil
        activeSheet = .clipGain(ClipGainPromptRequest(decibels: shared, clipCount: clips.count))
    }

    func applyClipGain(_ decibels: Double) {
        let ids = clipSelection.clipIDs
        guard !ids.isEmpty else {
            activeSheet = nil
            return
        }
        var edited = timeline.clips
        ClipEditing.setGain(clipIDs: ids, decibels: decibels, in: &edited)
        activeSheet = nil
        guard edited != timeline.clips else { return }
        commitTimelineEdit("Adjust Gain") { timeline in
            timeline.clips = edited
        }
    }

    /// Pulls the dragged edges onto a nearby clip edge, the playhead or a section marker; otherwise
    /// snaps the reference clip to the beat grid. Holding Control drags freely. The change applies
    /// to the whole selection.
    private func updateClipDrag(_ request: ClipDragRequest) {
        pendingShiftDeselectID = nil
        let snapsFreely = PointerModifiers.current.control
        switch request {
        case .move(let reference, let rawDelta, let copy):
            let moving = selectedClips.isEmpty ? [reference] : selectedClips
            let earliest = moving.map(\.timelineStartSeconds).min() ?? reference.timelineStartSeconds
            let edges = moving.flatMap { [$0.timelineStartSeconds, $0.timelineEndSeconds] }
            let delta: TimeInterval
            if snapsFreely {
                delta = rawDelta
                snapGuideTime = nil
            } else if let snap = magneticSnap(edges: edges, rawDelta: rawDelta) {
                delta = snap.delta
                snapGuideTime = snap.target
            } else {
                delta = snappedToBeat(reference.timelineStartSeconds + rawDelta) - reference.timelineStartSeconds
                snapGuideTime = nil
            }
            clipDrag = .move(delta: max(delta, -earliest), copy: copy)
        case .trim(let reference, let edge, let rawTime):
            let edgeTime = edge == .leading ? reference.timelineStartSeconds : reference.timelineEndSeconds
            let delta: TimeInterval
            if snapsFreely {
                delta = rawTime - edgeTime
                snapGuideTime = nil
            } else if let snap = magneticSnap(edges: [edgeTime], rawDelta: rawTime - edgeTime) {
                delta = snap.delta
                snapGuideTime = snap.target
            } else {
                delta = snappedToBeat(rawTime) - edgeTime
                snapGuideTime = nil
            }
            clipDrag = .trim(edge: edge, delta: delta)
        case .fade(let clipID, let edge, let fade):
            // Fades are not snapped: their length is set by ear, not by the grid.
            snapGuideTime = nil
            clipDrag = .fade(clipID: clipID, edge: edge, fade: fade)
        }
    }

    private func commitClipDrag() {
        snapGuideTime = nil
        guard let drag = clipDrag else { return }
        clipDrag = nil
        let ids = clipSelection.clipIDs
        switch drag {
        case .move(let delta, let copy):
            guard abs(delta) > ClipEditing.tolerance else { return }
            if copy {
                commitTimelineEdit("Copy Clips") { timeline in
                    clipSelection = ClipSelection(ClipEditing.copy(clipIDs: ids, by: delta, in: &timeline.clips))
                }
            } else {
                commitTimelineEdit("Move Clips") { timeline in
                    ClipEditing.move(clipIDs: ids, by: delta, in: &timeline.clips)
                }
            }
        case .trim(let edge, let delta):
            guard abs(delta) > ClipEditing.tolerance else { return }
            let durations = Dictionary(uniqueKeysWithValues: song.sortedTracks.map { ($0.id, viewModel.fileDuration(for: $0)) })
            commitTimelineEdit("Trim Clips") { timeline in
                ClipEditing.trim(
                    clipIDs: ids,
                    edge: edge,
                    by: delta,
                    sourceDuration: { durations[$0] ?? 0 },
                    in: &timeline.clips
                )
            }
        case .fade(let clipID, let edge, let fade):
            commitFade(fade, edge: edge, clipID: clipID)
        }
        clipSelection.retain(existing: timeline.clips)
    }

    /// A context-menu action on a clip outside the selection first makes it the only selected clip.
    /// Split uses the edit selection, so it decides that itself.
    private func performClipMenuAction(_ action: ClipMenuAction, clipID: UUID) {
        let clipWasSelected = clipSelection.contains(clipID)
        if action != .split, action != .paste, !clipWasSelected {
            clipSelection = ClipSelection([clipID])
        }
        switch action {
        case .cut: cutClips()
        case .copy: copyClips()
        case .paste: pasteClips()
        case .mute: toggleMuteClips()
        case .split: splitAtEditSelection(clickedClipID: clipID, clipWasSelected: clipWasSelected)
        case .join: joinSelectedClips()
        case .duplicate: duplicateSelectedClips()
        case .adjustGain: beginAdjustGain()
        case .fadeShape(let shape): setSelectedFadeShape(shape)
        case .removeFades: removeSelectedFades()
        case .delete:
            // Deleting a clip outside the selection removes that clip, not the range.
            if !clipWasSelected {
                editSelection = nil
            }
            removeClipSelection()
        }
    }

    /// Rows run MIDI first, then audio. The drag selects each clip the range overlaps on those rows.
    private func updateRangeDrag(from start: CGPoint, to current: CGPoint, modifiers _: PointerModifiers) {
        let ids = displayedTrackIDs
        guard !ids.isEmpty else { return }
        let frames = laneFrames
        func row(at y: CGFloat) -> Int {
            frames.rowIndex(at: y)
        }
        let lowRow = min(row(at: start.y), row(at: current.y))
        let highRow = max(row(at: start.y), row(at: current.y))
        let startTime = snappedToBeat(time(atX: start.x))
        let endTime = snappedToBeat(time(atX: current.x))
        editSelection = ClipRangeDrag(
            start: min(startTime, endTime),
            end: max(startTime, endTime),
            firstRow: lowRow,
            lastRow: highRow
        )
        pendingShiftDeselectID = nil
        clipDrag = nil
        let trackIDs = Set(ids[lowRow...highRow])
        selectedTrackIDs = trackIDs
        clipSelection = ClipSelection(
            ClipSelection.clipIDs(
                in: timeline.clips,
                trackIDs: trackIDs,
                from: startTime,
                to: endTime
            )
        )
    }

    func time(atX x: CGFloat) -> TimeInterval {
        TimelineLayout.time(at: x, duration: timelineDuration, contentWidth: timelineContentWidth)
    }
}
