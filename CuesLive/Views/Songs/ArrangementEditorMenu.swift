import SwiftUI

/// Section-level edits. Each one moves, copies, or removes the audio on every track along with
/// the section's marker.
struct ArrangementSectionActions {
    let sections: [SongSection]
    let move: (_ sectionID: UUID, _ toIndex: Int) -> Void
    let duplicate: (_ sectionID: UUID) -> Void
    let remove: (_ sectionID: UUID) -> Void
    let rename: (_ sectionID: UUID, _ name: String) -> Void
    /// `nil` goes back to the automatic color.
    let setColor: (_ sectionID: UUID, _ colorIndex: Int?) -> Void
}

struct ArrangementEditorMenu: View {
    let actions: ArrangementSectionActions

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            AppSectionHeader(title: "Song Arrangement")

            Text("Click a name to rename it, and the swatch to pick a color. Drag to reorder. Reordering, duplicating, or removing a section edits the audio on every track.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)

            if actions.sections.isEmpty {
                AppEmptyState(
                    title: "No Sections",
                    systemImage: "music.note.list",
                    description: "Add a section marker on the ruler or import an Ableton file."
                )
                .frame(minWidth: 300, minHeight: 180)
            } else {
                List {
                    ForEach(Array(actions.sections.enumerated()), id: \.element.id) { index, section in
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "line.3.horizontal")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)

                            SectionColorMenu(index: index, section: section) { colorIndex in
                                actions.setColor(section.id, colorIndex)
                            }

                            VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                                SectionNameField(name: section.name) { name in
                                    actions.rename(section.id, name)
                                }
                                Text("\(formatTime(section.timelineStartSeconds)) – \(formatTime(section.timelineEndSeconds))")
                                    .font(AppTypography.caption.monospacedDigit())
                                    .foregroundStyle(AppColors.textSecondary)
                            }

                            Spacer()

                            Button {
                                actions.duplicate(section.id)
                            } label: {
                                Image(systemName: "plus.square.on.square")
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .buttonStyle(.borderless)
                            .help("Duplicate section")

                            Button(role: .destructive) {
                                actions.remove(section.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove section")
                        }
                        .padding(.vertical, AppSpacing.xxxs)
                    }
                    .onMove(perform: move)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minWidth: 380, minHeight: 220, maxHeight: 520)
                #if os(iOS)
                .environment(\.editMode, .constant(.active))
                #endif
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfaceElevated, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private func formatTime(_ value: TimeInterval) -> String {
        let totalSeconds = max(0, Int(value.rounded()))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func move(from source: IndexSet, to destination: Int) {
        guard let index = source.first, index < actions.sections.count else { return }
        actions.move(actions.sections[index].id, destination)
    }
}

/// The section's name, edited in place. Saves on Return or when focus leaves; an empty name
/// goes back to the old one.
private struct SectionNameField: View {
    let name: String
    let onCommit: (String) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Section name", text: $draft)
            .textFieldStyle(.plain)
            .font(AppTypography.bodyMedium)
            .foregroundStyle(AppColors.textPrimary)
            .focused($isFocused)
            .onAppear { draft = name }
            .onChange(of: name) { _, newName in
                if !isFocused { draft = newName }
            }
            .onSubmit(commit)
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            draft = name
            return
        }
        if trimmed != name {
            onCommit(trimmed)
        }
    }
}

/// A swatch of the section's color; picking one sets it, Automatic follows the position.
private struct SectionColorMenu: View {
    let index: Int
    let section: SongSection
    let onPick: (Int?) -> Void

    private static let swatchSize: CGFloat = 14

    var body: some View {
        Menu {
            Button("Automatic") { onPick(nil) }
            Divider()
            ForEach(Array(ArrangementSectionPalette.names.enumerated()), id: \.offset) { colorIndex, name in
                Button {
                    onPick(colorIndex)
                } label: {
                    if section.colorIndex == colorIndex {
                        Label(name, systemImage: "checkmark")
                    } else {
                        Text(name)
                    }
                }
            }
        } label: {
            Circle()
                .fill(ArrangementSectionPalette.colors(for: index, picked: section.colorIndex).accent)
                .frame(width: Self.swatchSize, height: Self.swatchSize)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Section color")
    }
}
