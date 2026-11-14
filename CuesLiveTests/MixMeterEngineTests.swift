import AVFoundation
import XCTest
@testable import CuesLive

/// Drives the real engine: the meter hears the music track and not the click track.
final class MixMeterEngineTests: XCTestCase {
    private let sampleRate = 48_000.0

    private func writeSine(amplitude: Float, seconds: Double) throws -> URL {
        let frames = Int(sampleRate * seconds)
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
        pcm.frameLength = AVAudioFrameCount(frames)
        let channel = try XCTUnwrap(pcm.floatChannelData)[0]
        for frame in 0..<frames {
            channel[frame] = amplitude * Float(sin(2 * Double.pi * 997 * Double(frame) / sampleRate))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("meter-\(UUID().uuidString).caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: pcm)
        return url
    }

    func testMeterMeasuresMusicAndLeavesOutClick() throws {
        let seconds = 4.0
        let musicURL = try writeSine(amplitude: 0.1, seconds: seconds)
        let clickURL = try writeSine(amplitude: 0.9, seconds: seconds)
        defer {
            try? FileManager.default.removeItem(at: musicURL)
            try? FileManager.default.removeItem(at: clickURL)
        }
        let clickGroup = UUID()
        let settings = AudioEngineManager.TrackSettings(
            volume: 1, isMuted: false, isSolo: false,
            trimStart: 0, trimEnd: seconds, bypassesArrangementMapping: true
        )
        let engine = AudioEngineManager()
        try engine.loadPreparedTracks([
            AudioEngineManager.PreparedTrackPayload(
                id: UUID(), buffer: try StreamingStemBuffer(url: musicURL), settings: settings, groupID: nil
            ),
            AudioEngineManager.PreparedTrackPayload(
                id: UUID(), buffer: try StreamingStemBuffer(url: clickURL), settings: settings, groupID: clickGroup
            ),
        ])
        engine.setMixMeterExcludedGroups([clickGroup])
        engine.installCaptureTapForTesting(silenceSpeakers: true) { _, _ in }
        defer { engine.removeCaptureTapForTesting(); engine.stop() }

        engine.play()
        try XCTSkipUnless(engine.isPlaying, "needs a working audio output device")

        var analyzer = MixLoudnessAnalyzer(sampleRate: engine.mixMeterBus.sampleRate)
        let deadline = Date().addingTimeInterval(2.5)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
            engine.mixMeterBus.read { left, right, count in
                analyzer.process(left: left, right: right, count: count)
            }
        }
        let readings = analyzer.readings(at: 0)
        // The mono music stem feeds both sides at -20 dBFS: about -20 LUFS. With the click
        // counted, it would read about -1 LUFS.
        XCTAssertEqual(readings.momentary, -20, accuracy: 1)
        XCTAssertGreaterThan(readings.measuredSeconds, 1.5)
    }
}
