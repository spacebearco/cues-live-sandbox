#if os(macOS)
import SwiftUI

/// The live window's song browser, on the leading side of the setlist: song folders in a narrow
/// column that folds away, then the selected folder's songs.
@MainActor
struct LiveSongBrowser<Songs: View>: View {
    static var foldersVisibleStorageKey: String { "liveSongBrowserFoldersVisible" }

    static func minimumWidth(showsFolders: Bool) -> CGFloat {
        LivePlaybackSidebarMetrics.minimumSidebarWidth + (showsFolders ? folderColumnWidth : 0)
    }

    private static var folderColumnWidth: CGFloat { 180 }

    @Binding var folderSelection: LiveSongFolderList.Item?
    @ViewBuilder let songs: () -> Songs

    @AppStorage(Self.foldersVisibleStorageKey) private var showsFolders = true

    var body: some View {
        HStack(spacing: 0) {
            if showsFolders {
                LiveSongFolderList(selection: $folderSelection)
                    .frame(width: Self.folderColumnWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                Divider()
            }

            songs()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) { foldersToggle }
        }
        .background(AppColors.backgroundSecondary)
        .clipped()
    }

    private var foldersToggle: some View {
        HStack {
            Button {
                withAnimation(AppAnimation.springSmooth) { showsFolders.toggle() }
            } label: {
                Label(showsFolders ? "Hide Folders" : "Folders", systemImage: "sidebar.left")
                    .font(AppTypography.caption)
            }
            .buttonStyle(.borderless)
            .help(showsFolders ? "Fold the folder list away" : "Show the folder list")

            Spacer()
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.backgroundSecondary)
    }
}
#endif
