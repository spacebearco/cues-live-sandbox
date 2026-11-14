import XCTest
@testable import CuesLive

/// 120 bpm in 4/4: a bar is 2 s.
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

    func testSectionQuantizeIsPlannedBySections() {
        XCTAssertNil(ShowJumpPlanner.plan(
            clickedTime: 9, now: 1, quantize: .section, tempoChanges: tempo, timeSignatureChanges: meters
        ))
    }

    func testStoppedJumpGoesToTheGridLine() {
        XCTAssertEqual(ShowJumpPlanner.gridStart(containing: 9.3, quantize: .bar, tempoChanges: tempo, timeSignatureChanges: meters), 8, accuracy: 1e-6)
        XCTAssertEqual(ShowJumpPlanner.gridStart(containing: 9.3, quantize: .section, tempoChanges: tempo, timeSignatureChanges: meters), 9.3, accuracy: 1e-6)
    }

    func testCueFiresOnTheNextBarLine() {
        XCTAssertEqual(ShowJumpPlanner.fireTime(after: 2.7, quantize: .bar, tempoChanges: tempo, timeSignatureChanges: meters) ?? 0, 4, accuracy: 1e-6)
        XCTAssertNil(ShowJumpPlanner.fireTime(after: 2.7, quantize: .section, tempoChanges: tempo, timeSignatureChanges: meters))
    }

    func testFadeInEntersTheSectionAfterTheLeadBars() {
        // Section at 8 s, two 2 s bars of run-up, from a stop: start at 4 s, fade for 4 s.
        let stopped = ShowJumpPlanner.sectionEntry(
            to: 8, from: 30, leadBars: 2, keepsBeatPhase: false, tempoChanges: tempo, timeSignatureChanges: meters
        )
        XCTAssertEqual(stopped, ShowJumpPlanner.SectionEntry(start: 4, duration: 4))
    }

    func testFadeInKeepsThePlaceInTheBarWhilePlaying() throws {
        // Playing at 11.5 s: three quarters through a bar. The jump lands three quarters
        // through the first run-up bar, so the click carries on in time.
        let entry = try XCTUnwrap(ShowJumpPlanner.sectionEntry(
            to: 8, from: 11.5, leadBars: 2, keepsBeatPhase: true, tempoChanges: tempo, timeSignatureChanges: meters
        ))
        XCTAssertEqual(entry.start, 5.5, accuracy: 1e-6)
        XCTAssertEqual(entry.duration, 2.5, accuracy: 1e-6)
    }

    func testFadeInHasNoEntryWithoutBarsOrRoom() {
        XCTAssertNil(ShowJumpPlanner.sectionEntry(
            to: 8, from: 0, leadBars: 2, keepsBeatPhase: false, tempoChanges: [], timeSignatureChanges: []
        ))
        XCTAssertNil(ShowJumpPlanner.sectionEntry(
            to: 0, from: 5, leadBars: 2, keepsBeatPhase: false, tempoChanges: tempo, timeSignatureChanges: meters
        ))
        XCTAssertNil(ShowJumpPlanner.sectionEntry(
            to: 8, from: 0, leadBars: 0, keepsBeatPhase: false, tempoChanges: tempo, timeSignatureChanges: meters
        ))
    }

    func testFadeLengthFollowsTheSongsBars() {
        XCTAssertEqual(FadeButtonSettings.duration(bars: 4, at: 5, tempoChanges: tempo, timeSignatureChanges: meters), 8, accuracy: 1e-6)
        XCTAssertEqual(FadeButtonSettings.duration(bars: 2, at: 0, tempoChanges: [], timeSignatureChanges: []), 4, accuracy: 1e-6)
    }

    func testASavedBeatSettingFallsBackToEndOfSection() {
        XCTAssertNil(ShowQuantize(rawValue: "beat"))
        XCTAssertEqual(ShowQuantize.allCases, [.section, .bar])
    }
}
