import Foundation

/// Show or Edit, for the whole app.
/// Show is for the gig: a click on the playing song cues a jump that lands on the musical grid
/// (`ShowQuantize`), and anything that could go wrong mid-song is locked: opening the song
/// editor (and with it solo and every edit), and output routing.
/// Edit is for setting up: clicks move the playhead right there, and nothing is locked.
enum SetlistPlayMode: String, CaseIterable, Identifiable {
    case show
    case edit

    var id: String { rawValue }
    var title: String { self == .show ? "Show" : "Edit" }

    static let storageKey = "setlistPlayMode"
    /// A fresh install starts in Edit, so setting up songs and outputs is not locked.
    static let defaultMode: SetlistPlayMode = .edit

    /// Shown wherever Show mode has locked something.
    static let lockedExplanation = "Locked in Show mode. Switch the setlist to Edit to change this."
}

/// When a cued section fires. A cue always jumps to the start of the chosen section; this
/// picks the moment it happens.
enum ShowQuantize: String, CaseIterable, Identifiable {
    /// When the section playing now ends.
    case section
    /// On the next bar line.
    case bar
    /// On the next beat.
    case beat

    var id: String { rawValue }
    var title: String {
        switch self {
        case .section: "End of Section"
        case .bar: "Next Bar"
        case .beat: "Next Beat"
        }
    }

    static let storageKey = "setlistShowQuantize"
}

/// Plans when cued jumps fire on the bar or beat grid. Beats are quarter notes, as on the
/// editor grid.
enum ShowJumpPlanner {
    /// The next bar or beat line after `now`; `nil` for `.section`, which fires at the end of the
    /// section playing (the setlist knows its sections).
    static func fireTime(
        after now: TimeInterval,
        quantize: ShowQuantize,
        tempoChanges: [TempoChange],
        timeSignatureChanges: [TimeSignatureChange]
    ) -> TimeInterval? {
        guard !tempoChanges.isEmpty else { return nil }
        switch quantize {
        case .bar: return nextBarStart(after: now, tempoChanges, timeSignatureChanges)
        case .beat: return nextBeatStart(after: now, tempoChanges, timeSignatureChanges)
        case .section: return nil
        }
    }

    struct Jump: Equatable {
        /// Where playback lands: the start of the clicked bar or beat.
        let target: TimeInterval
        /// The next bar or beat line after now, where the jump happens.
        let fireTime: TimeInterval
    }

    static func plan(
        clickedTime: TimeInterval,
        now: TimeInterval,
        quantize: ShowQuantize,
        tempoChanges: [TempoChange],
        timeSignatureChanges: [TimeSignatureChange]
    ) -> Jump? {
        guard !tempoChanges.isEmpty else { return nil }
        switch quantize {
        case .bar:
            return Jump(
                target: barStart(containing: clickedTime, tempoChanges, timeSignatureChanges),
                fireTime: nextBarStart(after: now, tempoChanges, timeSignatureChanges)
            )
        case .beat:
            return Jump(
                target: beatStart(containing: clickedTime, tempoChanges, timeSignatureChanges),
                fireTime: nextBeatStart(after: now, tempoChanges, timeSignatureChanges)
            )
        case .section:
            return nil
        }
    }

    /// The grid line at or before `time`, for a jump made while stopped.
    static func gridStart(
        containing time: TimeInterval,
        quantize: ShowQuantize,
        tempoChanges: [TempoChange],
        timeSignatureChanges: [TimeSignatureChange]
    ) -> TimeInterval {
        guard !tempoChanges.isEmpty else { return max(0, time) }
        switch quantize {
        case .bar: return barStart(containing: time, tempoChanges, timeSignatureChanges)
        case .beat: return beatStart(containing: time, tempoChanges, timeSignatureChanges)
        case .section: return max(0, time)
        }
    }

    private static func barStart(
        containing time: TimeInterval,
        _ tempo: [TempoChange],
        _ meters: [TimeSignatureChange]
    ) -> TimeInterval {
        let measure = MeasureTiming.measureIndex(at: max(0, time), tempoChanges: tempo, timeSignatureChanges: meters)
        return MeasureTiming.timeAtStartOfMeasure(measure, tempoChanges: tempo, timeSignatureChanges: meters)
    }

    private static func nextBarStart(
        after time: TimeInterval,
        _ tempo: [TempoChange],
        _ meters: [TimeSignatureChange]
    ) -> TimeInterval {
        let measure = MeasureTiming.measureIndex(at: max(0, time), tempoChanges: tempo, timeSignatureChanges: meters)
        return MeasureTiming.timeAtStartOfMeasure(measure + 1, tempoChanges: tempo, timeSignatureChanges: meters)
    }

    /// The bar, and the whole quarter notes into it, that `time` falls in.
    private static func beatPosition(
        _ time: TimeInterval,
        _ tempo: [TempoChange],
        _ meters: [TimeSignatureChange]
    ) -> (measure: Int, beat: Double, beatsInMeasure: Double, timeline: TempoTimeline) {
        let timeline = TempoTimeline(tempoChanges: tempo, timeSignatureChanges: meters)
        let quarters = timeline.tick(atSeconds: max(0, time)) / Double(TempoChange.ticksPerQuarter)
        let measure = MeasureTiming.measureIndex(atBeat: quarters, tempoChanges: tempo, timeSignatureChanges: meters)
        let start = MeasureTiming.beatAtStartOfMeasure(measure, timeSignatureChanges: meters)
        let signature = MeasureTiming.numeratorDenominatorForMeasure(measure, changes: meters)
        let length = MeasureTiming.beatsPerMeasure(numerator: signature.numerator, denominator: signature.denominator)
        // A hair of tolerance so a time sitting exactly on a beat counts as that beat.
        return (measure, floor(quarters - start + 1e-6), length, timeline)
    }

    private static func beatStart(
        containing time: TimeInterval,
        _ tempo: [TempoChange],
        _ meters: [TimeSignatureChange]
    ) -> TimeInterval {
        let position = beatPosition(time, tempo, meters)
        let tick = TempoTimeline.tick(measure: position.measure, beatOffset: max(0, position.beat), timeSignatureChanges: meters)
        return position.timeline.seconds(atTick: tick)
    }

    private static func nextBeatStart(
        after time: TimeInterval,
        _ tempo: [TempoChange],
        _ meters: [TimeSignatureChange]
    ) -> TimeInterval {
        let position = beatPosition(time, tempo, meters)
        let next = position.beat + 1
        guard next < position.beatsInMeasure - 1e-6 else {
            return MeasureTiming.timeAtStartOfMeasure(position.measure + 1, tempoChanges: tempo, timeSignatureChanges: meters)
        }
        let tick = TempoTimeline.tick(measure: position.measure, beatOffset: next, timeSignatureChanges: meters)
        return position.timeline.seconds(atTick: tick)
    }
}
