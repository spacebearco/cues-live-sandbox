import Foundation

extension SongFolderImporter {
    /// Turns chosen folders into song folders. A folder that holds stems (or an Ableton set)
    /// is one song; a folder that holds only subfolders, such as a "Songs" folder, stands for
    /// each of its subfolders, so a whole library imports in one pass.
    static func songFolders(from chosenURLs: [URL]) -> [URL] {
        var result: [URL] = []
        for url in chosenURLs {
            let subfolders = childFoldersIfContainer(url)
            if subfolders.isEmpty {
                result.append(url)
            } else {
                result.append(contentsOf: subfolders)
            }
        }
        return result
    }

    /// Child folders of `url` when it has no song files of its own; otherwise empty.
    private static func childFoldersIfContainer(_ url: URL) -> [URL] {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let children = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let hasSongFiles = children.contains { child in
            let ext = child.pathExtension.lowercased()
            return supportedExtensions.contains(ext) || ext == "als"
        }
        guard !hasSongFiles else { return [] }

        return children
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
