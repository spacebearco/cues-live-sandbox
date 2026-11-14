import SwiftUI

/// The bar line where the Insert Bars prompt will open time.
struct InsertBarsRequest: Identifiable {
    let id = UUID()
    let measure: Int
}

extension EditView {
    /// Opens the Insert Bars prompt at the bar line nearest `time`.
    func beginInsertBars(at time: TimeInterval) {
        let tempo = normalizedTempoChanges
        let meter = normalizedTimeSignatureChanges
        let containing = MeasureTiming.measureIndex(at: max(0, time), tempoChanges: tempo, timeSignatureChanges: meter)
        let start = MeasureTiming.timeAtStartOfMeasure(containing, tempoChanges: tempo, timeSignatureChanges: meter)
        let next = MeasureTiming.timeAtStartOfMeasure(containing + 1, tempoChanges: tempo, timeSignatureChanges: meter)
        let measure = time - start > next - time ? containing + 1 : containing
        activeSheet = .insertBars(InsertBarsRequest(measure: max(1, measure)))
    }

    func insertBarsPrompt(for request: InsertBarsRequest) -> some View {
        InsertBarsPrompt(
            measure: request.measure,
            onCancel: { activeSheet = nil },
            onInsert: { barCount in
                activeSheet = nil
                insertBars(barCount, beforeMeasure: request.measure)
            }
        )
    }

    /// Opens `barCount` empty bars at the start of `measure`. Tempo and meter changes at or
    /// after that bar move with the music, so the new bars keep the tempo and meter of the
    /// bar before them.
    func insertBars(_ barCount: Int, beforeMeasure measure: Int) {
        guard barCount > 0, measure >= 1 else { return }
        clearMarkerCue()
        clipSelection.deselectAll()
        performUndoableChange(barCount == 1 ? "Insert Bar" : "Insert Bars") {
            let shiftedTempo = normalizedTempoChanges.map { change in
                guard !change.isOrigin, change.startMeasure >= measure else { return change }
                return TempoChange(
                    id: change.id,
                    startMeasure: change.startMeasure + barCount,
                    beatOffset: change.beatOffset,
                    bpm: change.bpm,
                    sortOrder: change.sortOrder
                )
            }
            let shiftedMeter = normalizedTimeSignatureChanges.map { change in
                guard change.startMeasure > 1, change.startMeasure >= measure else { return change }
                return TimeSignatureChange(
                    id: change.id,
                    numerator: change.numerator,
                    denominator: change.denominator,
                    startMeasure: change.startMeasure + barCount,
                    sortOrder: change.sortOrder
                )
            }
            let start = MeasureTiming.timeAtStartOfMeasure(
                measure,
                tempoChanges: shiftedTempo,
                timeSignatureChanges: shiftedMeter
            )
            let end = MeasureTiming.timeAtStartOfMeasure(
                measure + barCount,
                tempoChanges: shiftedTempo,
                timeSignatureChanges: shiftedMeter
            )

            tempoChanges = shiftedTempo
            timeSignatureChanges = shiftedMeter
            ClipEditing.insertSpace(at: start, length: end - start, timeline: &timeline, midiEvents: &midiEvents)

            persistProjectState()
            viewModel.syncTempoMap(normalizedTempoChanges, timeSignatureChanges: normalizedTimeSignatureChanges)
            syncPlayback()
            reconfigureMIDI()
            prepareSectionAnnouncements()
        }
    }
}
