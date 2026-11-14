import XCTest
@testable import CuesLive

/// 120 bpm in 4/4: a beat is 0.5 s and a bar 2 s.
final class ShowJumpPlannerTests: XCTestCase {
    private let tempo = [TempoChange(startMeasure: 1, bpm: 120)]
    private let meters = [TimeSignatureChange(numerator: 4, denominator: 4, startMeasure: 1)]

    func testBarJumpLandsOnClickedBarAtTheNextBarLine() throws {
        let jump = try XCTUnwrap(ShowJumpPlanner.plan(
            clickedTime: 9.3, now: 2.7, quantize: .bar, tempoChanges: tempo, timeSignatureChanges: meters
        ))
        XCTAssertEqual(jump.target, 8, accuracy: 1e-6)
        XCTAssertEqual(jump.fireTime, 4, accuracy: 1e-6)
    }

    func testBeatJumpLandsOnClickedBeatAtTheNextBeat() throws {
        let jump = try XCTUnwrap(ShowJumpPlanner.plan(
            clickedTime: 9.3, now: 2.7, quantize: .beat, tempoChanges: tempo, timeSignatureChanges: meters
        ))
        XCTAssertEqual(jump.target, 9, accuracy: 1e-6)
        XCTAssertEqual(jump.fireTime, 3, accuracy: 1e-6)
    }

    func testBeatJumpOnTheLastBeatFiresOnTheNextBar() throws {
        let jump = try XCTUnwrap(ShowJumpPlanner.plan(
            clickedTime: 1, now: 3.6, quantize: .beat, tempoChanges: tempo, timeSignatureChanges: meters
        ))
        XCTAssertEqual(jump.fireTime, 4, accuracy: 1e-6)
    }

    func testSectionQuantizeIsPlannedBySections() {
        XCTAssertNil(ShowJumpPlanner.plan(
            clickedTime: 9, now: 1, quantize: .section, tempoChanges: tempo, timeSignatureChanges: meters
        ))
    }

    func testStoppedJumpGoesToTheGridLine() {
        XCTAssertEqual(ShowJumpPlanner.gridStart(containing: 9.3, quantize: .bar, tempoChanges: tempo, timeSignatureChanges: meters), 8, accuracy: 1e-6)
        XCTAssertEqual(ShowJumpPlanner.gridStart(containing: 9.3, quantize: .beat, tempoChanges: tempo, timeSignatureChanges: meters), 9, accuracy: 1e-6)
    }
}
