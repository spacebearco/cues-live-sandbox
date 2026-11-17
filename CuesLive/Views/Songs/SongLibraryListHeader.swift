#if os(macOS)
import SwiftUI

/// Column titles above the macOS library list, lined up with `SongLibraryListRow`'s tempo, key
/// and meter columns. "Sig" is short for time signature; the full name is in the tooltip.
struct SongLibraryListHeader: View {
    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Text("Title")
                .frame(maxWidth: .infinity, alignment: .leading)
            column("BPM", width: SongLibraryListRow.tempoColumnWidth, help: "Tempo (BPM)")
            column("Key", width: SongLibraryListRow.keyColumnWidth, help: "Key")
            column("Sig", width: SongLibraryListRow.meterColumnWidth, help: "Time Signature")
        }
        .font(AppTypography.caption2Emphasized)
        .textCase(.uppercase)
        .foregroundStyle(AppColors.textTertiary)
        .accessibilityHidden(true)
    }

    private func column(_ title: String, width: CGFloat, help: String) -> some View {
        Text(title)
            .lineLimit(1)
            .frame(width: width, alignment: .trailing)
            .help(help)
    }
}
#endif
