import Foundation
import Observation

/// Drives the setlist meter: samples the playing engine's mix about 30 times a second.
@MainActor
@Observable
final class MixMeterModel {
    private(set) var readings = MixMeterReadings()

    @ObservationIgnored private let sampler = MixMeterSampler()
    @ObservationIgnored private var attachedEngineID: ObjectIdentifier?

    /// Samples `engine` until the calling task is cancelled. Each meter view runs this in its own
    /// `.task`, so a view the layout rebuilds can never stop another one's loop. Switching
    /// engines (an overlap handoff) starts the measurement over; the same engine carries on.
    func run(on engine: AudioEngineManager) async {
        let id = ObjectIdentifier(engine)
        if id != attachedEngineID {
            attachedEngineID = id
            await sampler.attach(engine.mixMeterBus)
        }
        while !Task.isCancelled {
            let now = ProcessInfo.processInfo.systemUptime
            if let readings = await sampler.sample(at: now) {
                publish(readings)
            }
            try? await Task.sleep(for: .milliseconds(33))
        }
    }

    func resetMeasurement() {
        Task { [sampler] in await sampler.resetMeasurement() }
    }

    private func publish(_ newReadings: MixMeterReadings) {
        guard newReadings != readings else { return }
        readings = newReadings
    }
}
