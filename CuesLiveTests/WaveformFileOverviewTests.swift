import XCTest
@testable import CuesLive

final class WaveformFileOverviewTests: XCTestCase {
    private func makeOverview(channelCount: Int) -> WaveformFileOverview {
        let pyramid = WaveformOverview(sampleCount: 0, level0: [])
        return WaveformFileOverview(
            sampleRate: 48_000,
            channels: Array(repeating: pyramid, count: channelCount)
        )
    }

    func testUnsplitTrackDrawsEveryChannel() {
        XCTAssertEqual(makeOverview(channelCount: 2).drawnChannels(for: nil), [0, 1])
        XCTAssertEqual(makeOverview(channelCount: 1).drawnChannels(for: nil), [0])
    }

    func testSplitTrackDrawsOnlyItsChannel() {
        let stereo = makeOverview(channelCount: 2)
        XCTAssertEqual(stereo.drawnChannels(for: 0), [0])
        XCTAssertEqual(stereo.drawnChannels(for: 1), [1])
    }

    func testChannelPastTheLastClampsToIt() {
        XCTAssertEqual(makeOverview(channelCount: 1).drawnChannels(for: 1), [0])
        XCTAssertEqual(makeOverview(channelCount: 2).drawnChannels(for: 3), [1])
        XCTAssertEqual(makeOverview(channelCount: 0).drawnChannels(for: 1), [])
    }
}
