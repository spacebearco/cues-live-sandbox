import Foundation
import Observation

/// Drives the setlist meter: samples the playing engine's mix about 30 times a second.
@MainActor
@Observable
final class MixMeterModel {
    private(set) var readings = MixMeterReadings()

    @ObservationIgnored private let sampler = MixMeterSampler()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var engineID: ObjectIdentifier?

    /// Meters `engine`, leaving out tracks in `excludedGroupIDs`. Safe to call repeatedly;
    /// switching engines (an overlap handoff) starts the measurement over.
    func meter(_ engine: AudioEngineManager, excludingGroups excludedGroupIDs: Set<UUID>) {
        engine.setMixMeterExcludedGroups(excludedGroupIDs)
        let id = ObjectIdentifier(engine)
        guard id != engineID else { return }
        engineID = id
        let bus = engine.mixMeterBus
        loop?.cancel()
        loop = Task { [weak self, sampler] in
            await sampler.attach(bus)
            while !Task.isCancelled {
                let now = ProcessInfo.processInfo.systemUptime
                if let readings = await sampler.sample(at: now) {
                    self?.publish(readings)
                }
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        engineID = nil
    }

    func resetMeasurement() {
        Task { [sampler] in await sampler.resetMeasurement() }
    }

    private func publish(_ newReadings: MixMeterReadings) {
        guard newReadings != readings else { return }
        readings = newReadings
    }
}
