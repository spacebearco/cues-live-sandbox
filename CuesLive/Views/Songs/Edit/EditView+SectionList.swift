import SwiftUI

/// Name and color edits from the Song Arrangement list, so every section can be set up in one place.
extension EditView {
    func renameSection(id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = timeline.markers.firstIndex(where: { $0.id == id }),
              timeline.markers[index].name != trimmed else { return }
        commitTimelineEdit("Rename Section") { timeline in
            timeline.markers[index].name = trimmed
        }
    }

    func setSectionColor(id: UUID, to colorIndex: Int?) {
        guard let index = timeline.markers.firstIndex(where: { $0.id == id }),
              timeline.markers[index].colorIndex != colorIndex else { return }
        commitTimelineEdit("Section Color") { timeline in
            timeline.markers[index].colorIndex = colorIndex
        }
    }
}
