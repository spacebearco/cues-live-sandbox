import Foundation

/// How the Fade button fades: its length in bars, and whether a low-pass sweep follows it.
/// Set from the button's right-click menu and remembered between launches.
enum FadeButtonSettings {
    static let barsKey = "fadeButtonBars"
    static let filterSweepKey = "fadeButtonFilterSweep"
    static let defaultBars = 4
    static let barOptions = [1, 2, 4, 8, 16]
    /// Bars of run-up when a fade-in re-enters a section. 0 fades in where the song is.
    static let entryBarsKey = "fadeInEntryBars"
    static let defaultEntryBars = 2
    static let entryBarOptions = [0, 1, 2, 4]

    static var entryBars: Int {
        UserDefaults.standard.object(forKey: entryBarsKey) as? Int ?? defaultEntryBars
    }

    static func entryLabel(forBars bars: Int) -> String {
        bars == 0 ? "Where the Song Is" : "\(label(forBars: bars)) Before the Section"
    }

    static var bars: Int {
        let stored = UserDefaults.standard.integer(forKey: barsKey)
        return stored > 0 ? stored : defaultBars
    }

    /// On unless turned off.
    static var sweepsFilter: Bool {
        UserDefaults.standard.object(forKey: filterSweepKey) as? Bool ?? true
    }

    static func label(forBars bars: Int) -> String {
        bars == 1 ? "1 bar" : "\(bars) bars"
    }

    /// Seconds for `bars` bars from the bar playing at `time`, following the song's tempo and
    /// meter. Without a tempo map, a bar is two seconds (120 BPM in 4/4).
    static func duration(
        bars: Int = FadeButtonSettings.bars,
        at time: TimeInterval,
        tempoChanges: [TempoChange],
        timeSignatureChanges: [TimeSignatureChange]
    ) -> TimeInterval {
        let count = max(1, bars)
        guard !tempoChanges.isEmpty else { return Double(count) * 2 }
        let measure = MeasureTiming.measureIndex(
            at: max(0, time),
            tempoChanges: tempoChanges,
            timeSignatureChanges: timeSignatureChanges
        )
        let start = MeasureTiming.timeAtStartOfMeasure(measure, tempoChanges: tempoChanges, timeSignatureChanges: timeSignatureChanges)
        let end = MeasureTiming.timeAtStartOfMeasure(measure + count, tempoChanges: tempoChanges, timeSignatureChanges: timeSignatureChanges)
        return end > start ? end - start : Double(count) * 2
    }
}
