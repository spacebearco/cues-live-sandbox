import AVFoundation
import XCTest
@testable import CuesLive

final class ArrangementSwapFadeTests: XCTestCase {
    private func makeBuffer(frames: Int, value: Float = 1) throws -> AVAudioPCMBuffer {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 1_000, channels: 2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
        buffer.frameLength = AVAudioFrameCount(frames)
        let channels = try XCTUnwrap(buffer.floatChannelData)
        for channel in 0..<2 {
            for frame in 0..<frames { channels[channel][frame] = value }
        }
        return buffer
    }

    private func samples(_ buffer: AVAudioPCMBuffer, channel: Int = 0) -> [Float] {
        guard let data = buffer.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: data[channel], count: Int(buffer.frameLength)))
    }

    /// 1 kHz rate with a 10 ms fade-in: 10 frames.
    func testFadeOutEndsSilentThenFadeInRampsBackOverTenMilliseconds() throws {
        var fade = ArrangementSwapFade(sampleRate: 1_000)
        let outgoing = try makeBuffer(frames: 4)
        fade.fadeOut(UnsafeMutableAudioBufferListPointer(outgoing.mutableAudioBufferList), frameCount: 4)
        XCTAssertEqual(samples(outgoing), [0.75, 0.5, 0.25, 0])
        XCTAssertEqual(samples(outgoing, channel: 1).last, 0)

        let first = try makeBuffer(frames: 6)
        fade.fadeIn(UnsafeMutableAudioBufferListPointer(first.mutableAudioBufferList), frameCount: 6)
        XCTAssertEqual(samples(first).first, 0)
        XCTAssertEqual(samples(first).last ?? 0, 0.5, accuracy: 1e-6)

        let second = try makeBuffer(frames: 6)
        fade.fadeIn(UnsafeMutableAudioBufferListPointer(second.mutableAudioBufferList), frameCount: 6)
        XCTAssertEqual(samples(second).first ?? 0, 0.6, accuracy: 1e-6)
        XCTAssertEqual(Array(samples(second).suffix(2)), [1, 1])

        let after = try makeBuffer(frames: 3)
        fade.fadeIn(UnsafeMutableAudioBufferListPointer(after.mutableAudioBufferList), frameCount: 3)
        XCTAssertEqual(samples(after), [1, 1, 1])
    }

    func testCancelStopsAPendingFadeIn() throws {
        var fade = ArrangementSwapFade(sampleRate: 1_000)
        let outgoing = try makeBuffer(frames: 2)
        fade.fadeOut(UnsafeMutableAudioBufferListPointer(outgoing.mutableAudioBufferList), frameCount: 2)
        fade.cancel()
        let next = try makeBuffer(frames: 3)
        fade.fadeIn(UnsafeMutableAudioBufferListPointer(next.mutableAudioBufferList), frameCount: 3)
        XCTAssertEqual(samples(next), [1, 1, 1])
    }
}
