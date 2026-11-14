import SwiftData
import SwiftUI

/// Edits a song's key, starting tempo and starting meter from the library, without the editor.
@MainActor
struct SongQuickEditPopover: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let song: Song

    @State private var values = SongMetadataEditor.Values(key: nil, bpm: TempoChange.defaultBPM, numerator: 4, denominator: 4)
    @State private var bpmText = ""
    @State private var errorMessage: String?

    private var parsedBPM: Double? {
        guard let bpm = Double(bpmText.trimmingCharacters(in: .whitespaces)),
              TempoChange.validBPMRange.contains(bpm) else { return nil }
        return bpm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(song.name)
                .font(.headline)
                .lineLimit(1)

            Form {
                Picker("Key", selection: $values.key) {
                    Text("None").tag(SongMusicalKey?.none)
                    ForEach(SongMusicalKey.allCases, id: \.self) { key in
                        Text(key.displayName).tag(SongMusicalKey?.some(key))
                    }
                }
                TextField("Tempo (BPM)", text: $bpmText)
                Stepper("Beats per bar: \(values.numerator)", value: $values.numerator, in: 1...32)
                Picker("Beat unit", selection: $values.denominator) {
                    ForEach(TimeSignatureChange.validDenominators, id: \.self) { unit in
                        Text("\(unit)").tag(unit)
                    }
                }
            }

            Text("Changes the tempo and meter at bar 1. Later changes in the song stay as they are.")
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(parsedBPM == nil)
            }
        }
        .padding(AppSpacing.lg)
        .frame(width: 300)
        .onAppear(perform: load)
    }

    private func load() {
        values = SongMetadataEditor.values(for: song)
        bpmText = Self.format(bpm: values.bpm)
    }

    private func save() {
        guard let bpm = parsedBPM else { return }
        var updated = values
        updated.bpm = bpm
        do {
            try SongMetadataEditor.apply(updated, to: song, context: modelContext)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func format(bpm: Double) -> String {
        bpm.rounded() == bpm ? String(Int(bpm)) : String(format: "%.2f", bpm)
    }
}
