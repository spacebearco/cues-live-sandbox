import Foundation
import SwiftData

/// Changes a song's key, starting tempo and starting meter without opening the editor.
/// Later tempo and meter changes in the song are left alone.
enum SongMetadataEditor {
    struct Values: Equatable {
        var key: SongMusicalKey?
        var bpm: Double
        var numerator: Int
        var denominator: Int
    }

    /// The song's current key, starting tempo and starting meter.
    static func values(for song: Song) -> Values {
        let state = SongProjectBridge.projectStateOrDefaults(for: song)
        return Values(
            key: song.baseKeyRaw.flatMap { SongMusicalKey(spelling: $0) },
            bpm: state.tempoChanges.referenceBPM,
            numerator: state.timeSignatureChanges.referenceNumerator,
            denominator: state.timeSignatureChanges.referenceDenominator
        )
    }

    /// Writes `values` to the song and its project file.
    static func apply(_ values: Values, to song: Song, context: ModelContext) throws {
        let state = SongProjectBridge.projectStateOrDefaults(for: song)
        let tempo = replacingStartTempo(in: state.tempoChanges, bpm: values.bpm)
        let meters = replacingStartMeter(
            in: state.timeSignatureChanges,
            numerator: values.numerator,
            denominator: values.denominator
        )
        song.baseKeyRaw = values.key?.rawValue
        song.bpm = tempo.referenceBPM
        song.timeSignatureNumerator = meters.referenceNumerator
        song.timeSignatureDenominator = meters.referenceDenominator
        try SongProjectBridge.syncProjectFile(
            for: song,
            context: context,
            timeline: state.timeline,
            tempoChanges: tempo,
            timeSignatureChanges: meters
        )
    }

    /// `changes` with the tempo at bar 1 set to `bpm`, clamped to the valid range.
    static func replacingStartTempo(in changes: [TempoChange], bpm: Double) -> [TempoChange] {
        let clamped = min(max(bpm, TempoChange.validBPMRange.lowerBound), TempoChange.validBPMRange.upperBound)
        let normalized = changes.normalizedEnsuringInitialMarker(defaultBPM: clamped)
        return normalized.map { change in
            guard change.isOrigin else { return change }
            return TempoChange(
                id: change.id,
                startMeasure: change.startMeasure,
                beatOffset: change.beatOffset,
                bpm: clamped,
                sortOrder: change.sortOrder
            )
        }
    }

    /// `changes` with the meter at bar 1 set to `numerator`/`denominator`.
    static func replacingStartMeter(
        in changes: [TimeSignatureChange],
        numerator: Int,
        denominator: Int
    ) -> [TimeSignatureChange] {
        let safeNumerator = max(1, numerator)
        let safeDenominator = TimeSignatureChange.validDenominators.contains(denominator)
            ? denominator
            : TimeSignatureChange.defaultDenominator
        let normalized = changes.normalizedEnsuringInitialMarker(
            defaultNumerator: safeNumerator,
            defaultDenominator: safeDenominator
        )
        guard let first = normalized.sortedByMeasure.first else { return normalized }
        return normalized.map { change in
            guard change.id == first.id else { return change }
            return TimeSignatureChange(
                id: change.id,
                numerator: safeNumerator,
                denominator: safeDenominator,
                startMeasure: change.startMeasure,
                sortOrder: change.sortOrder
            )
        }
    }
}
