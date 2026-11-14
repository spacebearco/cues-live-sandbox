import Foundation

/// Reads an engine's mix-meter bus and runs the loudness analysis, off the main actor.
actor MixMeterSampler {
    private var bus: MixMeterBus?
    private var analyzer: MixLoudnessAnalyzer?
    private var busGeneration = -1

    /// Switches to another engine's bus. Measurement starts over.
    func attach(_ bus: MixMeterBus?) {
        self.bus = bus
        analyzer = nil
        busGeneration = -1
    }

    /// Starts the integrated reading, maximums and clip light over.
    func resetMeasurement() {
        analyzer?.resetMeasurement()
    }

    /// Measures everything played since the last call. A newly loaded song starts the
    /// integrated reading over. `nil` when no bus is attached.
    func sample(at now: TimeInterval) -> MixMeterReadings? {
        guard let bus else { return nil }
        let rate = bus.sampleRate
        let generation = bus.generation
        // Take the analyzer out while it runs so its arrays are not copied on write.
        var working = analyzer ?? MixLoudnessAnalyzer(sampleRate: rate)
        analyzer = nil
        if rate > 0, working.sampleRate != rate {
            working = MixLoudnessAnalyzer(sampleRate: rate)
        } else if generation != busGeneration, busGeneration >= 0 {
            working.resetMeasurement()
        }
        busGeneration = generation
        bus.read { left, right, count in
            working.process(left: left, right: right, count: count)
        }
        let readings = working.readings(at: now)
        analyzer = working
        return readings
    }
}
