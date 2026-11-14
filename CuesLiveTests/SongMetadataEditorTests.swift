import XCTest
@testable import CuesLive

final class SongMetadataEditorTests: XCTestCase {
    func testStartTempoChangesAndLaterTempoStays() {
        let origin = TempoChange(startMeasure: 1, bpm: 100)
        let later = TempoChange(startMeasure: 17, bpm: 140)
        let result = SongMetadataEditor.replacingStartTempo(in: [origin, later], bpm: 128)
        XCTAssertEqual(result.referenceBPM, 128)
        XCTAssertEqual(result.first { $0.id == origin.id }?.bpm, 128)
        XCTAssertEqual(result.first { $0.id == later.id }?.bpm, 140)
    }

    func testStartTempoIsClampedToValidRange() {
        let result = SongMetadataEditor.replacingStartTempo(in: [TempoChange(startMeasure: 1, bpm: 100)], bpm: 5)
        XCTAssertEqual(result.referenceBPM, TempoChange.validBPMRange.lowerBound)
    }

    func testStartTempoAddedWhenMissing() {
        let result = SongMetadataEditor.replacingStartTempo(in: [], bpm: 90)
        XCTAssertEqual(result.referenceBPM, 90)
    }

    func testStartMeterChangesAndLaterMeterStays() {
        let origin = TimeSignatureChange(numerator: 4, denominator: 4, startMeasure: 1)
        let later = TimeSignatureChange(numerator: 7, denominator: 8, startMeasure: 9)
        let result = SongMetadataEditor.replacingStartMeter(in: [origin, later], numerator: 6, denominator: 8)
        XCTAssertEqual(result.referenceNumerator, 6)
        XCTAssertEqual(result.referenceDenominator, 8)
        XCTAssertEqual(result.first { $0.id == later.id }?.numerator, 7)
    }

    func testInvalidBeatUnitFallsBackToQuarter() {
        let result = SongMetadataEditor.replacingStartMeter(in: [], numerator: 3, denominator: 5)
        XCTAssertEqual(result.referenceNumerator, 3)
        XCTAssertEqual(result.referenceDenominator, 4)
    }
}
