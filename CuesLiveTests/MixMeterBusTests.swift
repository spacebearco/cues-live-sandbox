import AVFoundation
import XCTest
@testable import CuesLive

final class MixMeterBusTests: XCTestCase {
    private func add(_ bus: MixMeterBus, slot: Int, value: Float, frames: Int) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let channels = buffer.floatChannelData else { return XCTFail("buffer") }
        buffer.frameLength = AVAudioFrameCount(frames)
        for frame in 0..<frames {
            channels[0][frame] = value
            channels[1][frame] = -value
        }
        bus.add(slot: slot, buffers: UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList), frameCount: frames)
    }

    private func readAll(_ bus: MixMeterBus) -> (left: [Float], right: [Float]) {
        var left: [Float] = [], right: [Float] = []
        bus.read { l, r, count in
            left += UnsafeBufferPointer(start: l, count: count)
            right += UnsafeBufferPointer(start: r, count: count)
        }
        return (left, right)
    }

    func testSumsMeasuredTracksAndSkipsExcluded() {
        let bus = MixMeterBus()
        let drums = UUID(), bass = UUID(), click = UUID()
        let slots = bus.reset(sampleRate: 48_000, trackIDs: [drums, bass, click])
        for id in [drums, bass] { bus.setMeasured(true, trackID: id) }
        bus.setMeasured(false, trackID: click)

        add(bus, slot: slots[drums] ?? -1, value: 0.25, frames: 256)
        add(bus, slot: slots[bass] ?? -1, value: 0.5, frames: 256)
        add(bus, slot: slots[click] ?? -1, value: 1, frames: 256)

        let mix = readAll(bus)
        XCTAssertEqual(mix.left.count, 256)
        XCTAssertEqual(mix.left.first, 0.75)
        XCTAssertEqual(mix.right.last, -0.75)
    }

    func testWaitsForTheSlowestTrack() {
        let bus = MixMeterBus()
        let first = UUID(), second = UUID()
        let slots = bus.reset(sampleRate: 48_000, trackIDs: [first, second])
        bus.setMeasured(true, trackID: first)
        bus.setMeasured(true, trackID: second)

        add(bus, slot: slots[first] ?? -1, value: 0.5, frames: 512)
        add(bus, slot: slots[second] ?? -1, value: 0.5, frames: 128)
        XCTAssertEqual(readAll(bus).left.count, 128)

        add(bus, slot: slots[second] ?? -1, value: 0.5, frames: 384)
        let rest = readAll(bus).left
        XCTAssertEqual(rest.count, 384)
        XCTAssertEqual(rest.last, 1)
    }

    func testResetBumpsGeneration() {
        let bus = MixMeterBus()
        let before = bus.generation
        bus.reset(sampleRate: 44_100, trackIDs: [UUID()])
        XCTAssertEqual(bus.generation, before + 1)
        XCTAssertEqual(bus.sampleRate, 44_100)
    }

    func testExcludedGroupsMatchClickCuesAndTimecodeByName() {
        let groups = [
            TrackGroup(name: "Drums", sortOrder: 0),
            TrackGroup(name: " click ", sortOrder: 1),
            TrackGroup(name: "Cues", sortOrder: 2),
            TrackGroup(name: "TIMECODE", sortOrder: 3),
        ]
        let excluded = AudioEngineManager.mixMeterExcludedGroupIDs(in: groups)
        XCTAssertEqual(excluded, Set(groups.dropFirst().map(\.id)))
    }

    /// Regression: a left-out track (click, timecode) that never renders must not freeze the meter.
    func testLeftOutTrackThatNeverRendersDoesNotBlockTheMeter() {
        let bus = MixMeterBus()
        let music = UUID(), timecode = UUID()
        let slots = bus.reset(sampleRate: 48_000, trackIDs: [music, timecode])
        bus.setMeasured(true, trackID: music)
        bus.setMeasured(false, trackID: timecode)
        add(bus, slot: slots[music] ?? -1, value: 0.5, frames: 256)
        XCTAssertEqual(readAll(bus).left.count, 256)
    }

    /// Regression: a measured track that stops rendering altogether is skipped, not waited for.
    func testStalledMeasuredTrackIsSkipped() {
        let bus = MixMeterBus()
        let playing = UUID(), stalled = UUID()
        let slots = bus.reset(sampleRate: 48_000, trackIDs: [playing, stalled])
        bus.setMeasured(true, trackID: playing)
        bus.setMeasured(true, trackID: stalled)
        let frames = MixMeterBus.capacity / 4 + 512
        add(bus, slot: slots[playing] ?? -1, value: 0.25, frames: frames)
        XCTAssertEqual(readAll(bus).left.count, frames)
    }
}
