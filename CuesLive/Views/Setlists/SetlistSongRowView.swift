import SwiftUI

/// The header line of a song in the setlist: number or now-playing indicator, title, badges,
/// duration, and the row menu.
struct SetlistSongRowView<MenuContent: View>: View {
    let song: SetlistRowModel.Song
    let isCurrent: Bool
    let isFinished: Bool
    let isPlaying: Bool
    let showsMenu: Bool
    /// Whether the section list under the row is open. Nil when the song has no sections to show.
    var sectionsExpanded: Binding<Bool>? = nil
    @ViewBuilder let menu: () -> MenuContent

    private var detailText: String? {
        let parts = [song.keyText, song.bpmText].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            leadingIndicator
                .frame(width: 28)

            sectionsDisclosure

            VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                Text(song.title)
                    .font(isCurrent ? AppTypography.bodyEmphasized : AppTypography.bodyMedium)
                    .foregroundStyle(isFinished ? AppColors.textTertiary : AppColors.textPrimary)
                    .lineLimit(2)

                if let detailText {
                    Text(detailText)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            badges

            Text(song.durationText)
                .font(AppTypography.subheadline.monospacedDigit())
                .foregroundStyle(isCurrent ? AppColors.textSecondary : AppColors.textTertiary)
                .accessibilityLabel("Duration \(song.durationText)")

            if showsMenu {
                SetlistRowMenuButton(menu: menu)
            }
        }
        .frame(minHeight: AppSpacing.rowMinHeight)
        .opacity(isFinished ? 0.55 : 1)
    }

    /// Folds the song's sections open or closed. Keeps its width when a song has no sections,
    /// so titles stay aligned.
    private var sectionsDisclosure: some View {
        Button {
            withAnimation(AppAnimation.springSnappy) {
                sectionsExpanded?.wrappedValue.toggle()
            }
        } label: {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
                .rotationEffect(.degrees(sectionsExpanded?.wrappedValue == true ? 90 : 0))
                .frame(width: 20, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(sectionsExpanded == nil ? 0 : 1)
        .disabled(sectionsExpanded == nil)
        .accessibilityLabel(sectionsExpanded?.wrappedValue == true ? "Hide sections" : "Show sections")
        .help(sectionsExpanded?.wrappedValue == true ? "Hide sections" : "Show sections")
    }

    @ViewBuilder
    private var badges: some View {
        if song.hasMissingMedia {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColors.warning)
                .font(AppTypography.caption)
                .accessibilityLabel("Missing audio files")
                .help("Missing audio files — use Relink Missing Files in the menu")
        }

        if song.hasSmartGuide {
            SmartGuideBadge()
        }

        if let transition = song.transition {
            Image(systemName: transition.systemImage)
                .font(AppTypography.captionEmphasized)
                .foregroundStyle(transition.badgeColor)
                .accessibilityLabel("Transition to next: \(transition.label)")
                .help("Transition to next: \(transition.label)")
        }
    }

    @ViewBuilder
    private var leadingIndicator: some View {
        if isCurrent {
            Image(systemName: "speaker.wave.2.fill")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.accent)
                .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                .accessibilityLabel("Now playing")
        } else {
            Text("\(song.playbackIndex + 1)")
                .font(AppTypography.subheadline.monospacedDigit())
                .foregroundStyle(AppColors.textTertiary)
                .accessibilityHidden(true)
        }
    }
}
