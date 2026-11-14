import XCTest
@testable import CuesLive

final class MixLoudnessAnalyzerTests: XCTestCase {
    private let rate = 48_000.0

    private func feed(
        _ analyzer: inout MixLoudnessAnalyzer,
        seconds: Double,
        frequency: Double,
        amplitude: Float,
        phase: Double = 0
    ) {
        let count = Int(rate * seconds)
        var left = [Float](repeating: 0, count: count)
        for frame in 0..<count {
            left[frame] = amplitude * Float(sin(2 * Double.pi * frequency * Double(frame) / rate + phase))
        }
        left.withUnsafeBufferPointer { pointer in
            guard let base = pointer.baseAddress else { return }
            analyzer.process(left: base, right: base, count: count)
        }
    }

    /// BS.1770: a 997 Hz sine at 0 dBFS in both channels reads 0 LUFS, so -20 dBFS reads -20.
    func testStereoSineReadsItsLevelInLUFS() {
        var analyzer = MixLoudnessAnalyzer(sampleRate: rate)
        feed(&analyzer, seconds: 5, frequency: 997, amplitude: 0.1)
        let readings = analyzer.readings(at: 0)
        XCTAssertEqual(readings.integrated, -20, accuracy: 0.2)
        XCTAssertEqual(readings.momentary, -20, accuracy: 0.2)
        XCTAssertEqual(readings.shortTerm, -20, accuracy: 0.2)
        // A sine's RMS sits 3 dB under its peak.
        XCTAssertEqual(readings.rms, -23, accuracy: 0.1)
        XCTAssertEqual(readings.maxPeak, -20, accuracy: 0.05)
        XCTAssertFalse(readings.hasClipped)
    }

    /// A quarter-rate sine sampled between its crests: samples read about -3 dB, true peak about 0.
    func testTruePeakFindsInterSamplePeaks() {
        var analyzer = MixLoudnessAnalyzer(sampleRate: rate)
        feed(&analyzer, seconds: 0.5, frequency: rate / 4, amplitude: 1, phase: Double.pi / 4)
        let readings = analyzer.readings(at: 0)
        XCTAssertEqual(readings.maxPeak, -3, accuracy: 0.2)
        XCTAssertGreaterThan(readings.truePeak, -0.6)
    }

    func testSilenceStaysAtFloorAndGatesOut() {
        var analyzer = MixLoudnessAnalyzer(sampleRate: rate)
        feed(&analyzer, seconds: 2, frequency: 997, amplitude: 0)
        let readings = analyzer.readings(at: 0)
        XCTAssertEqual(readings.integrated, MixMeterReadings.floor)
        XCTAssertEqual(readings.peakLeft, MixMeterReadings.floor)
    }

    func testPeakFallsAfterHold() {
        var analyzer = MixLoudnessAnalyzer(sampleRate: rate)
        feed(&analyzer, seconds: 0.1, frequency: 997, amplitude: 0.5)
        let first = analyzer.readings(at: 10)
        XCTAssertEqual(first.holdLeft, first.peakLeft)
        // 0.2 s later with no signal: the bar falls 4 dB, the hold line stays.
        let later = analyzer.readings(at: 10.2)
        XCTAssertEqual(later.peakLeft, first.peakLeft - 4, accuracy: 0.01)
        XCTAssertEqual(later.holdLeft, first.holdLeft)
    }

    func testResetClearsIntegratedAndClip() {
        var analyzer = MixLoudnessAnalyzer(sampleRate: rate)
        feed(&analyzer, seconds: 1, frequency: 997, amplitude: 1.2)
        XCTAssertTrue(analyzer.readings(at: 0).hasClipped)
        analyzer.resetMeasurement()
        let readings = analyzer.readings(at: 0.03)
        XCTAssertFalse(readings.hasClipped)
        XCTAssertEqual(readings.integrated, MixMeterReadings.floor)
        XCTAssertEqual(readings.measuredSeconds, 0)
    }
}
