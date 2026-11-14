import SwiftUI

/// Show / Edit switch for the setlist, with the Show mode jump quantize beside it.
/// Show: a click on the playing song cues a jump on the next bar, beat or section, and the
/// song editor (with solo) and output routing are locked. Edit: a click moves the playhead
/// right there, and nothing is locked.
struct SetlistModeControls: View {
    @AppStorage(SetlistPlayMode.storageKey) private var playMode: SetlistPlayMode = SetlistPlayMode.defaultMode
    @AppStorage(ShowQuantize.storageKey) private var quantize: ShowQuantize = .section

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if playMode == .show {
                Picker("Jump", selection: $quantize) {
                    ForEach(ShowQuantize.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .help("Show mode: a click jumps on the next \(quantize.title.lowercased()).")
            }

            Picker("Mode", selection: $playMode) {
                ForEach(SetlistPlayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help(playMode == .show
                ? "Show mode: clicks cue quantized jumps. Editing, solo and routing are locked."
                : "Edit mode: clicks move the playhead anywhere.")
        }
    }
}
