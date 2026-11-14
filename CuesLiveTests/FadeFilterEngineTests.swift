import AVFoundation
import XCTest
@testable import CuesLive

/// Drives the real engine: the Fade button's filter sweep must audibly cut a faded group's highs.
final class FadeFilterEngineTests: XCTestCase {
    private final class Capture: @unchecked Sendable {
        private let lock = NSLock()
        private var samples: [Float] = []
        func append(_ buffer: AVAudioPCMBuffer) {
            guard let channel = buffer.floatChannelData?[0] else { return }
            lock.lock(); defer { lock.unlock() }
            samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        }
        func takeRMS() -> Double {
            lock.lock(); defer { lock.unlock() }
            let tail = samples.suffix(12_000)
            samples = []
            guard !tail.isEmpty else { return 0 }
            return (tail.reduce(0.0) { $0 + Double($1 * $1) } / Double(tail.count)).squareRoot()
        }
    }

    private func wait(_ seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
    }

    func testClosedSweepCutsAFadedGroupsHighs() throws {
        let rate = 48_000.0, seconds = 8.0
        let frames = Int(rate * seconds)
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
        pcm.frameLength = AVAudioFrameCount(frames)
        let data = try XCTUnwrap(pcm.floatChannelData)[0]
        for frame in 0..<frames { data[frame] = 0.5 * Float(sin(2 * Double.pi * 5_000 * Double(frame) / rate)) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sweep-\(UUID()).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: pcm)

        let trackID = UUID(), groupID = UUID()
        let settings = AudioEngineManager.TrackSettings(volume: 1, isMuted: false, isSolo: false, trimStart: 0, trimEnd: seconds)
        let engine = AudioEngineManager()
        try engine.loadPreparedTracks([
            .init(id: trackID, buffer: try StreamingStemBuffer(url: url), settings: settings, groupID: groupID),
        ])
        let capture = Capture()
        engine.installCaptureTapForTesting(trackID: trackID, silenceSpeakers: true) { buffer, _ in capture.append(buffer) }
        defer { engine.removeCaptureTapForTesting(); engine.stop() }
        engine.play()
        try XCTSkipUnless(engine.isPlaying, "needs a working audio output device")

        wait(1)
        let open = capture.takeRMS()
        var closed = GroupMixSnapshot(volumeByGroupID: [groupID: 1], mutedGroupIDs: [], ungroupedVolume: 1, ungroupedIsMuted: false)
        closed.fadeFilter = .init(closure: 1, groupIDs: [groupID], includesUngrouped: false)
        engine.applyGroupMix(closed)
        wait(1)
        let filtered = capture.takeRMS()

        XCTAssertGreaterThan(open, 0.3)
        XCTAssertLessThan(filtered, open * 0.01, "5 kHz should be cut by more than 40 dB with the sweep closed")
    }

    func testSweepCurveLeadsTheFade() {
        XCTAssertEqual(GroupMixFadeController.sweepCurve(0), 0)
        XCTAssertEqual(GroupMixFadeController.sweepCurve(1), 1)
        XCTAssertGreaterThan(GroupMixFadeController.sweepCurve(0.25), 0.5)
    }
}
