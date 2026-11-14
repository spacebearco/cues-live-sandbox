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

    func testPanicLandsOneBarBeforeTheSectionPlaying() {
        let sections = [
            SongSection(id: UUID(), name: "Verse", timelineStartSeconds: 0, timelineEndSeconds: 8, loops: false),
            SongSection(id: UUID(), name: "Chorus", timelineStartSeconds: 8, timelineEndSeconds: 16, loops: false),
        ]
        // In the chorus (starts at 8 s): one 2 s bar of pre-roll.
        XCTAssertEqual(ShowJumpPlanner.panicTarget(now: 11.3, sections: sections, tempoChanges: tempo, timeSignatureChanges: meters), 6, accuracy: 1e-6)
        // The first section has nothing before it.
        XCTAssertEqual(ShowJumpPlanner.panicTarget(now: 3, sections: sections, tempoChanges: tempo, timeSignatureChanges: meters), 0, accuracy: 1e-6)
        // No sections: the bar before the one playing.
        XCTAssertEqual(ShowJumpPlanner.panicTarget(now: 5.2, sections: [], tempoChanges: tempo, timeSignatureChanges: meters), 2, accuracy: 1e-6)
        // No tempo: the section start.
        XCTAssertEqual(ShowJumpPlanner.panicTarget(now: 11.3, sections: sections, tempoChanges: [], timeSignatureChanges: []), 8, accuracy: 1e-6)
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
