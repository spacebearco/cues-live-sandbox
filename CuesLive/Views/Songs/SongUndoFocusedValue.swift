#if os(macOS)
import SwiftUI

/// Publishes the editor's undo state to the Edit menu. Reading `canUndo` and friends here, not in
/// `SongDetailView.body`, means an edit that changes them (every mute, solo or knob release)
/// refreshes only this modifier instead of re-rendering the whole editor.
struct SongUndoFocusedValue: ViewModifier {
    let undoController: SongUndoController

    func body(content: Content) -> some View {
        content.focusedValue(
            \.songUndoActions,
            SongUndoActions(
                canUndo: undoController.canUndo,
                canRedo: undoController.canRedo,
                undoActionName: undoController.undoActionName,
                redoActionName: undoController.redoActionName,
                undo: { undoController.undo() },
                redo: { undoController.redo() }
            )
        )
    }
}
#endif
