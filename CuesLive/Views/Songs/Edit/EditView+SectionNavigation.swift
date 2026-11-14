import SwiftUI

extension EditView {
    /// ← and → jump to the previous or next section. Stopped, the edit head moves there; while
    /// playing, playback jumps there too. Ignored with modifiers (Control-Option arrows resize lanes)
    /// and while typing.
    func handleSectionArrowKey(_ press: KeyPress) -> KeyPress.Result {
        // Arrow keys arrive flagged as keypad keys; any other modifier means another shortcut.
        guard isTimelineFocused, !Self.isTypingText,
              press.modifiers.subtracting(.numericPad).isEmpty,
              !displaySections.isEmpty else { return .ignored }
        let from = audioEngine.isPlaying ? audioEngine.currentTime : insertionTime
        let target = press.key == .leftArrow
            ? displaySections.previousSectionStart(from: from)
            : displaySections.nextSectionStart(from: from)
        guard let target else { return .handled }
        editSelection = nil
        insertionTime = max(0, target)
        if audioEngine.isPlaying {
            viewModel.seekAndPlay(to: insertionTime)
        }
        return .handled
    }

    /// Shown over the timeline while Detect Sections is listening to the song.
    @ViewBuilder
    var detectingSectionsStatus: some View {
        if isDetectingSections {
            HStack(spacing: AppSpacing.xs) {
                ProgressView()
                    .controlSize(.small)
                Text("Detecting sections…")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(AppColors.textPrimary)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, TimelineLayout.rulerTotalHeight + AppSpacing.sm)
            .transition(.opacity)
            .allowsHitTesting(false)
        }
    }
}
