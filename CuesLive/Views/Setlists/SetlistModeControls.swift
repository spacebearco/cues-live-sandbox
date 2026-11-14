import SwiftUI

/// Show / Edit switch for the setlist, with the Show mode jump quantize beside it.
/// Show: a click on the playing song cues that section, and everything that isn't for the gig
/// is hidden or locked (the Jump setting, the song editor with solo, output routing). Edit: a
/// click moves the playhead right there, the Jump setting shows, and nothing is locked.
struct SetlistModeControls: View {
    @AppStorage(SetlistPlayMode.storageKey) private var playMode: SetlistPlayMode = SetlistPlayMode.defaultMode
    @AppStorage(ShowQuantize.storageKey) private var quantize: ShowQuantize = .section

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            // A loud badge so the mode reads at a glance from across a stage.
            Label(playMode == .show ? "SHOW" : "EDIT", systemImage: playMode == .show ? "lock.fill" : "pencil")
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppColors.Live.modeBadgeText)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, 3)
                .background(playMode == .show ? AppColors.Live.showModeBadge : AppColors.Live.editModeBadge, in: Capsule())
                .accessibilityHidden(true)

            // Set up in Edit mode. Cues keep firing on it in Show mode, where it is hidden.
            if playMode == .edit {
                Picker("Jump", selection: $quantize) {
                    ForEach(ShowQuantize.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .help("A cued section starts at: \(quantize.title.lowercased()).")
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
                ? "Show mode: clicks cue sections. Editing, solo and routing are locked."
                : "Edit mode: clicks move the playhead anywhere.")
        }
    }
}
