import AVFoundation
import XCTest
@testable import CuesLive

final class LowPassSweepTests: XCTestCase {
    private let rate = 48_000.0

    /// RMS of a sine at `frequency` after running it through the filter at `closure` for 0.5 s.
    private func rms(frequency: Double, closure: Double) throws -> Double {
        let filter = LowPassSweep(sampleRate: rate, channelCount: 1)
        let block = 512
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(block)))
        buffer.frameLength = AVAudioFrameCount(block)
        let list = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        var sum = 0.0, count = 0
        for blockIndex in 0..<Int(rate * 0.5) / block {
            let samples = try XCTUnwrap(buffer.floatChannelData)[0]
            for frame in 0..<block {
                let n = Double(blockIndex * block + frame)
                samples[frame] = Float(sin(2 * Double.pi * frequency * n / rate))
            }
            filter.process(list, frameCount: block, closure: closure)
            if blockIndex > 40 {
                for frame in 0..<block { sum += Double(samples[frame] * samples[frame]); count += 1 }
            }
        }
        return (sum / Double(count)).squareRoot()
    }

    func testOpenFilterLeavesAudioUntouched() throws {
        XCTAssertEqual(try rms(frequency: 5_000, closure: 0), 0.5.squareRoot(), accuracy: 0.001)
    }

    func testClosedFilterCutsHighsAndKeepsLows() throws {
        let closedHigh = try rms(frequency: 5_000, closure: 1)
        let closedLow = try rms(frequency: 60, closure: 1)
        XCTAssertLessThan(closedHigh, 0.005)
        XCTAssertGreaterThan(closedLow, 0.6)
    }

    func testCutoffSweepsExponentially() {
        XCTAssertEqual(LowPassSweep.cutoffHz(forClosure: 0), 20_000, accuracy: 0.01)
        XCTAssertEqual(LowPassSweep.cutoffHz(forClosure: 1), 150, accuracy: 0.01)
        XCTAssertEqual(LowPassSweep.cutoffHz(forClosure: 0.5), (20_000.0 * 150).squareRoot(), accuracy: 0.5)
    }
}
