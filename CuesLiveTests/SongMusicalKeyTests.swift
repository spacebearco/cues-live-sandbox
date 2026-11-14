import XCTest
@testable import CuesLive

final class SongMusicalKeyTests: XCTestCase {
    func testDisplayReturnsTheSelectedKey() {
        XCTAssertEqual(SongMusicalKey.display(baseRaw: "Bb"), "A#/Bb")
        XCTAssertEqual(SongMusicalKey.display(baseRaw: "C"), "C")
        XCTAssertNil(SongMusicalKey.display(baseRaw: nil))
        XCTAssertNil(SongMusicalKey.display(baseRaw: "H"))
    }

    func testBlackKeysShowBothSpellings() {
        XCTAssertEqual(SongMusicalKey.display(baseRaw: "C#"), "C#/Db")
        XCTAssertEqual(SongMusicalKey.display(baseRaw: "Bb"), "A#/Bb")
        XCTAssertEqual(SongMusicalKey.display(baseRaw: "F#"), "F#/Gb")
        XCTAssertEqual(SongMusicalKey.allCases.count, 12)
    }

    func testAnySpellingMapsToItsPitchClass() {
        // Songs saved by builds that stored single flat/sharp spellings still read.
        XCTAssertEqual(SongMusicalKey.display(baseRaw: "Db"), "C#/Db")
        XCTAssertEqual(SongMusicalKey.display(baseRaw: "A#"), "A#/Bb")
        XCTAssertEqual(SongMusicalKey(spelling: "G#/Ab"), .aFlat)
        XCTAssertNil(SongMusicalKey(spelling: "H"))
    }

    func testTransposingThroughBlackKeys() {
        XCTAssertEqual(SongMusicalKey.display(baseRaw: "Db", transposeSemitones: 5), "F#/Gb")
        XCTAssertEqual(SongMusicalKey.display(baseRaw: "F#", transposeSemitones: 1), "G")
        XCTAssertEqual(SongMusicalKey.display(baseRaw: "D", transposeSemitones: 1), "D#/Eb")
    }

    func testTransportTextUsesEmDashWhenUnset() {
        XCTAssertEqual(SongMusicalKey.transportText(baseRaw: nil), "—")
        XCTAssertEqual(SongMusicalKey.transportText(baseRaw: "G"), "G")
    }
}
