import XCTest
@testable import CuesLive

final class SectionColorTests: XCTestCase {
    func testPickedColorSavesAndReachesTheSection() throws {
        let marker = ArrangementMarker(name: "Chorus", startSeconds: 10, colorIndex: 6)
        let decoded = try JSONDecoder().decode(ArrangementMarker.self, from: JSONEncoder().encode(marker))
        XCTAssertEqual(decoded.colorIndex, 6)
        let sections = SongTimeline(markers: [decoded]).sections(songEnd: 30)
        XCTAssertEqual(sections.first?.colorIndex, 6)
    }

    func testMarkersFromOlderFilesHaveAutomaticColor() throws {
        let legacy = Data(#"{"id":"6E3B2C0A-1111-4222-8333-944455556666","name":"Verse","startSeconds":0}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(ArrangementMarker.self, from: legacy).colorIndex)
    }

    func testAutomaticColorsKeepTheirSixColorCycle() {
        XCTAssertEqual(ArrangementSectionPalette.names.count, 9)
        let seventh = ArrangementSectionPalette.colors(for: 6)
        let first = ArrangementSectionPalette.colors(for: 0)
        XCTAssertEqual(seventh.accent, first.accent)
        XCTAssertNotEqual(ArrangementSectionPalette.colors(for: 0, picked: 6).accent, first.accent)
    }
}

final class SectionNavigationTests: XCTestCase {
    private let sections = SongTimeline(markers: [
        ArrangementMarker(name: "Intro", startSeconds: 0),
        ArrangementMarker(name: "Verse", startSeconds: 10),
        ArrangementMarker(name: "Chorus", startSeconds: 30),
    ]).sections(songEnd: 60)

    func testRightGoesToTheNextSectionAndStopsAfterTheLast() {
        XCTAssertEqual(sections.nextSectionStart(from: 0), 10)
        XCTAssertEqual(sections.nextSectionStart(from: 10), 30)
        XCTAssertNil(sections.nextSectionStart(from: 45))
    }

    func testLeftGoesToTheSectionStartThenThePreviousOne() {
        XCTAssertEqual(sections.previousSectionStart(from: 20), 10)
        XCTAssertEqual(sections.previousSectionStart(from: 10), 0)
        XCTAssertEqual(sections.previousSectionStart(from: 10.3), 0)
        XCTAssertEqual(sections.previousSectionStart(from: 0), 0)
    }
}
