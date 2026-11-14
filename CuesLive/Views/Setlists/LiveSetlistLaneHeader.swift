import SwiftUI

/// The header above a song's lane in the setlist waveform strip: its setlist number and name,
/// so each waveform is labelled like a track.
struct LiveSetlistLaneHeader: View {
    let number: Int
    let title: String
    let isCurrent: Bool
    let width: CGFloat

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Text("\(number)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(isCurrent ? AppColors.accent : AppColors.textTertiary)

            Text(title)
                .font(.caption.weight(isCurrent ? .semibold : .medium))
                .foregroundStyle(isCurrent ? AppColors.textPrimary : AppColors.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, AppSpacing.xs)
        .frame(width: width, height: LiveSetlistWaveformMetrics.laneHeaderHeight, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Song \(number), \(title)")
    }
}
