import Foundation
import Observation

@Observable
final class SongUndoController: NSObject {
    private let undoManager = UndoManager()
    private(set) var isApplyingUndo = false
    /// Bumped whenever the undo stack changes so SwiftUI observes `canUndo` / `canRedo`.
    private var stackRevision = 0

    var canUndo: Bool {
        _ = stackRevision
        return undoManager.canUndo
    }

    var canRedo: Bool {
        _ = stackRevision
        return undoManager.canRedo
    }

    var undoActionName: String? {
        _ = stackRevision
        return undoManager.undoActionName
    }

    var redoActionName: String? {
        _ = stackRevision
        return undoManager.redoActionName
    }

    override init() {
        super.init()
        undoManager.levelsOfUndo = 50
    }

    /// Records one undoable step. Undo calls `apply(before)`, redo calls `apply(after)`. `State` is
    /// whatever the step needs to restore: a whole `SongEditSnapshot` for editor edits, or only
    /// the track gains for a setlist fader move.
    func registerChange<State: Equatable>(
        actionName: String,
        before: State,
        after: State,
        apply: @escaping (State) -> Void
    ) {
        guard before != after else { return }
        guard !isApplyingUndo else { return }

        undoManager.registerUndo(withTarget: self) { target in
            target.applyState(before, actionName: actionName, paired: after, using: apply)
        }
        undoManager.setActionName(actionName)
        refreshStackState()
    }

    /// Drops every step, for when the closures they hold no longer point at a live editor.
    func removeAllActions() {
        undoManager.removeAllActions()
        refreshStackState()
    }

    func undo() {
        undoManager.undo()
        refreshStackState()
    }

    func redo() {
        undoManager.redo()
        refreshStackState()
    }

    private func refreshStackState() {
        stackRevision &+= 1
    }

    private func applyState<State: Equatable>(
        _ state: State,
        actionName: String,
        paired: State,
        using apply: @escaping (State) -> Void
    ) {
        isApplyingUndo = true
        apply(state)
        isApplyingUndo = false

        undoManager.registerUndo(withTarget: self) { target in
            target.applyState(paired, actionName: actionName, paired: state, using: apply)
        }
        undoManager.setActionName(actionName)
        refreshStackState()
    }
}
