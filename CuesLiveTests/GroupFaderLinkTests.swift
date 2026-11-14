import XCTest
@testable import CuesLive

final class GroupFaderLinkTests: XCTestCase {
    func testFaderSitsAtTheLoudestTrackTimesTheGroupLevel() {
        XCTAssertEqual(GroupFaderLink.level(groupVolume: 1, trackVolumes: [0.5, 0.8]), 0.8, accuracy: 1e-9)
        XCTAssertEqual(GroupFaderLink.level(groupVolume: 0.5, trackVolumes: [0.8]), 0.4, accuracy: 1e-9)
    }

    func testMovingTheFaderKeepsTheTracksBalance() {
        let scaled = GroupFaderLink.trackVolumes(scaling: [0.4, 0.8], groupVolume: 1, toLevel: 0.4)
        XCTAssertEqual(scaled[0], 0.2, accuracy: 1e-9)
        XCTAssertEqual(scaled[1], 0.4, accuracy: 1e-9)
        XCTAssertEqual(GroupFaderLink.level(groupVolume: 1, trackVolumes: scaled), 0.4, accuracy: 1e-9)
    }

    func testTheGroupsOwnLevelIsLeftOutOfTheTrackGains() {
        let scaled = GroupFaderLink.trackVolumes(scaling: [1], groupVolume: 0.5, toLevel: 0.25)
        XCTAssertEqual(scaled[0], 0.5, accuracy: 1e-9)
    }

    func testSilentTracksAllTakeTheNewLevel() {
        XCTAssertEqual(GroupFaderLink.trackVolumes(scaling: [0, 0], groupVolume: 1, toLevel: 0.7), [0.7, 0.7])
    }

    func testAFadedOutGroupChangesNothing() {
        XCTAssertEqual(GroupFaderLink.trackVolumes(scaling: [0.5], groupVolume: 0, toLevel: 0.9), [0.5])
    }

    func testGainsStopAtTheTopOfTheFader() {
        let top = MixerFaderScale.linearGain(forDecibels: MixerFaderScale.maxBoostDB)
        let scaled = GroupFaderLink.trackVolumes(scaling: [1, 2], groupVolume: 1, toLevel: top * 2)
        XCTAssertEqual(scaled[1], top, accuracy: 1e-9)
    }
}
