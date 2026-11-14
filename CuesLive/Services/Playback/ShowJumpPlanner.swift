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
/// picks the moment it happens. A setting saved by an older build that no longer exists (Next
/// Beat) falls back to End of Section.
enum ShowQuantize: String, CaseIterable, Identifiable {
    /// When the section playing now ends.
    case section
    /// On the next bar line.
    case bar

    var id: String { rawValue }
    var title: String {
        switch self {
        case .section: "End of Section"
        case .bar: "Next Bar"
        }
    }

    static let storageKey = "setlistShowQuantize"
}

/// Plans when cued jumps fire on the bar grid.
enum ShowJumpPlanner {
    struct Jump: Equatable {
        /// Where playback lands: the start of the clicked bar.
        let target: TimeInterval
        /// The next bar line after now, where the jump happens.
        let fireTime: TimeInterval
    }

    /// The next bar line after `now`; `nil` for `.section`, which fires at the end of the
    /// section playing (the setlist knows its sections).
    static func fireTime(
        after now: TimeInterval,
        quantize: ShowQuantize,
        tempoChanges: [TempoChange],
        timeSignatureChanges: [TimeSignatureChange]
    ) -> TimeInterval? {
        guard quantize == .bar, !tempoChanges.isEmpty else { return nil }
        return barStart(containing: now, offsetBy: 1, tempoChanges, timeSignatureChanges)
    }

    /// For a song without sections: a jump to the clicked bar, on the next bar line.
    static func plan(
        clickedTime: TimeInterval,
        now: TimeInterval,
        quantize: ShowQuantize,
        tempoChanges: [TempoChange],
        timeSignatureChanges: [TimeSignatureChange]
    ) -> Jump? {
        guard let fireTime = fireTime(
            after: now,
            quantize: quantize,
            tempoChanges: tempoChanges,
            timeSignatureChanges: timeSignatureChanges
        ) else { return nil }
        return Jump(
            target: barStart(containing: clickedTime, offsetBy: 0, tempoChanges, timeSignatureChanges),
            fireTime: fireTime
        )
    }

    /// The bar line at or before `time`, for a jump made while stopped. `.section` keeps `time`.
    static func gridStart(
        containing time: TimeInterval,
        quantize: ShowQuantize,
        tempoChanges: [TempoChange],
        timeSignatureChanges: [TimeSignatureChange]
    ) -> TimeInterval {
        guard quantize == .bar, !tempoChanges.isEmpty else { return max(0, time) }
        return barStart(containing: time, offsetBy: 0, tempoChanges, timeSignatureChanges)
    }

    /// Start of the bar `time` is in, or of the bar `offset` bars later.
    private static func barStart(
        containing time: TimeInterval,
        offsetBy offset: Int,
        _ tempo: [TempoChange],
        _ meters: [TimeSignatureChange]
    ) -> TimeInterval {
        let measure = MeasureTiming.measureIndex(at: max(0, time), tempoChanges: tempo, timeSignatureChanges: meters)
        return MeasureTiming.timeAtStartOfMeasure(measure + offset, tempoChanges: tempo, timeSignatureChanges: meters)
    }
}
