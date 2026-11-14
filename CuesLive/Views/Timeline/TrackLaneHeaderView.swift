import SwiftUI

struct TrackLaneHeaderView: View {
    @Bindable var track: AudioTrack
    @Bindable private var audioEngine = AudioEngineManager.shared
    let laneHeight: CGFloat
    let isSelected: Bool
    let groups: [TrackGroup]
    let onSelect: (PointerModifiers) -> Void
    let onMixChange: () -> Void
    let onGroupChange: () -> Void
    let onManageGroups: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    /// Offered for tracks that play every channel of their file; `nil` hides it.
    var onSplitToMono: (() -> Void)?
    /// Drag distance downward from the press, in points.
    let onResize: (CGFloat) -> Void
    let onResizeEnded: () -> Void

    /// Fader values while a drag is in progress. They go straight to the audio engine and
    /// reach the saved track only when the drag ends: writing the model on every drag tick
    /// redraws the whole editor and makes it stutter.
    @State private var draftVolume: Double?
    @State private var draftPan: Double?

    private var trackColors: (header: Color, body: Color) {
        TrackGroupPalette.colors(for: track.group)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            headerControls
            TrackLevelMeter(trackID: track.id)
                .padding(.vertical, AppSpacing.compact)
                .padding(.trailing, AppSpacing.compact)
        }
        .frame(width: TimelineLayout.trackHeaderWidth, height: laneHeight, alignment: .topLeading)
        .clipped()
        .background {
            if isSelected {
                Rectangle()
                    .fill(AppColors.trackHeaderSelected)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Rename") {
                onRename()
            }
            if let onSplitToMono {
                Button("Split to Mono", action: onSplitToMono)
            }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .onTapGesture { onSelect(.current) }
        .overlay(alignment: .bottom) {
            TrackLaneResizeHandle(onChanged: onResize, onEnded: onResizeEnded)
                .frame(maxWidth: .infinity)
                .frame(height: 6)
                .offset(y: 2)
        }
    }

    /// Name, then the mix row, then the group, stacked from the top at fixed spacing. A taller
    /// lane adds room below them; nothing moves.
    private var headerControls: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            Text(track.displayName)
                .font(AppTypography.captionEmphasized)
                .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, minHeight: Self.rowHeight, maxHeight: Self.rowHeight, alignment: .leading)

            mixRow
            groupPicker
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.top, AppSpacing.xxs)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// M, S, gain and pan, evenly spaced, each the same height.
    private var mixRow: some View {
        HStack(spacing: Self.rowSpacing) {
            TrackMixButton(
                label: "M",
                isActive: track.isMuted,
                activeColor: AppColors.muteActive
            ) {
                track.isMuted.toggle()
                onMixChange()
            }

            TrackMixButton(
                label: "S",
                isActive: track.isSolo,
                activeColor: AppColors.soloActive
            ) {
                track.isSolo.toggle()
                onMixChange()
            }

            TrackVolumeField(
                volume: Binding(
                    get: { draftVolume ?? track.volume },
                    set: { draftVolume = $0 }
                ),
                onLiveChange: applyLiveMix,
                onEditingEnded: commitMixDrafts
            )

            TrackPanField(
                pan: Binding(
                    get: { draftPan ?? track.pan },
                    set: { draftPan = $0 }
                ),
                onLiveChange: applyLiveMix,
                onEditingEnded: commitMixDrafts
            )
        }
        .frame(height: Self.rowHeight)
    }

    private static let rowHeight: CGFloat = 22
    private static let rowSpacing = AppSpacing.compact

    private func applyLiveMix() {
        audioEngine.applyLiveTrackMix(
            id: track.id,
            volume: Float(draftVolume ?? track.volume),
            pan: Float(draftPan ?? track.pan)
        )
    }

    private func commitMixDrafts() {
        if let draftVolume, track.volume != draftVolume {
            track.volume = draftVolume
        }
        if let draftPan, track.pan != draftPan {
            track.pan = draftPan
        }
        draftVolume = nil
        draftPan = nil
        onMixChange()
    }

    private var groupPicker: some View {
        Menu {
            Button("No Group") {
                track.group = nil
                onGroupChange()
            }

            ForEach(groups) { group in
                Button(group.name) {
                    track.group = group
                    onGroupChange()
                }
            }

            Divider()

            Button("Manage Groups…") {
                onManageGroups()
            }
        } label: {
            HStack(spacing: AppSpacing.xxs) {
                Text(track.group?.name ?? "No Group")
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(AppTypography.Compact.glyph)
            }
            .font(AppTypography.caption2)
            .foregroundStyle(trackColors.body)
            .padding(.horizontal, AppSpacing.compact)
            .frame(maxWidth: .infinity, minHeight: Self.rowHeight, maxHeight: Self.rowHeight, alignment: .leading)
            .background(AppColors.Timeline.mixButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .controlSize(.small)
        .modifier(FlexibleControlSizing())
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.rowHeight)
    }
}

private struct FlexibleControlSizing: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.buttonSizing(.flexible)
        } else {
            content
        }
    }
}
