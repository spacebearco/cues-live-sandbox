import AVFoundation
import XCTest
@testable import CuesLive

/// Drives the real engine: arrangement edits made while a song plays must not leave gaps.
final class LiveEditPlaybackTests: XCTestCase {
    private let sampleRate = 48_000.0
    private let seconds = 30.0

    private final class Capture: @unchecked Sendable {
        private let lock = NSLock()
        private var samples: [Float] = []

        func append(_ buffer: AVAudioPCMBuffer) {
            guard let channel = buffer.floatChannelData?[0] else { return }
            lock.lock(); defer { lock.unlock() }
            samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        }

        func snapshot() -> [Float] {
            lock.lock(); defer { lock.unlock() }
            return samples
        }
    }

    private func writeTone() throws -> URL {
        let frames = Int(sampleRate * seconds)
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
        pcm.frameLength = AVAudioFrameCount(frames)
        let channel = try XCTUnwrap(pcm.floatChannelData)[0]
        for frame in 0..<frames {
            channel[frame] = 0.5 * Float(sin(2 * Double.pi * 440 * Double(frame) / sampleRate))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("live-edit-\(UUID().uuidString).caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: pcm)
        return url
    }

    /// Longest stretch, in milliseconds, where the tone drops out (3 ms windows under 0.1).
    private func longestDropoutMilliseconds(_ samples: ArraySlice<Float>) -> Double {
        let window = Int(sampleRate * 0.003)
        var longest = 0, run = 0
        var index = samples.startIndex
        while index + window <= samples.endIndex {
            let peak = samples[index..<(index + window)].reduce(0) { max($0, abs($1)) }
            run = peak < 0.1 ? run + 1 : 0
            longest = max(longest, run)
            index += window
        }
        return Double(longest) * 3
    }

    private func waitWhilePlaying(_ engine: AudioEngineManager, seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
    }

    func testSplitAndJumpWhilePlayingLeaveNoGap() throws {
        let url = try writeTone()
        defer { try? FileManager.default.removeItem(at: url) }
        let trackID = UUID()
        let settings = AudioEngineManager.TrackSettings(
            volume: 1, isMuted: false, isSolo: false, trimStart: 0, trimEnd: seconds
        )
        let engine = AudioEngineManager()
        try engine.loadPreparedTracks([
            AudioEngineManager.PreparedTrackPayload(
                id: trackID, buffer: try StreamingStemBuffer(url: url), settings: settings, groupID: nil
            ),
        ])
        let whole = TrackClip(trackID: trackID, timelineStartSeconds: 0, duration: seconds, sourceStartSeconds: 0)
        engine.setArrangement(SongPlaybackLayout(timeline: SongTimeline(markers: [], clips: [whole])))

        let capture = Capture()
        engine.installCaptureTapForTesting(trackID: trackID, silenceSpeakers: true) { buffer, _ in
            capture.append(buffer)
        }
        defer { engine.removeCaptureTapForTesting(); engine.stop() }
        engine.play()
        try XCTSkipUnless(engine.isPlaying, "needs a working audio output device")
        waitWhilePlaying(engine, seconds: 1)

        // A split ahead of the playhead changes nothing audible: no fade, no gap.
        let splitStart = capture.snapshot().count
        var clips = [whole]
        _ = ClipEditing.split(clipIDs: [whole.id], at: 10, in: &clips)
        engine.setArrangement(SongPlaybackLayout(timeline: SongTimeline(markers: [], clips: clips)))
        waitWhilePlaying(engine, seconds: 0.5)
        let splitEnd = capture.snapshot().count

        // Re-point the clip under the playhead far into the file, outside what is read ahead.
        var jumped = clips
        if let index = jumped.firstIndex(where: { $0.timelineStartSeconds == 0 }) {
            jumped[index].sourceStartSeconds = 18
        }
        engine.setArrangement(SongPlaybackLayout(timeline: SongTimeline(markers: [], clips: jumped)))
        waitWhilePlaying(engine, seconds: 0.5)

        let samples = capture.snapshot()
        XCTAssertGreaterThan(samples.count, Int(sampleRate * 1.5))
        XCTAssertEqual(longestDropoutMilliseconds(samples[splitStart..<splitEnd]), 0)
        // The jump fades out and back in within a block or two; it must not wait on the disk.
        XCTAssertLessThan(longestDropoutMilliseconds(samples[splitEnd...]), 20)
    }
}
