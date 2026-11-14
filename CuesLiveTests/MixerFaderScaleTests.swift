import XCTest
@testable import CuesLive

final class MixerFaderScaleTests: XCTestCase {
    func testMarkersAreTenDecibelStepsThroughPlusTen() {
        XCTAssertEqual(
            MixerFaderScale.markerDecibels,
            [10, 0, -10, -20, -30, -40, -50, -60]
        )
    }

    func testUnityGainSitsOnTheZeroMarker() {
        let unity = MixerFaderScale.normalizedPosition(forLinearGain: 1)
        let zero = MixerFaderScale.normalizedPosition(forDecibels: 0)
        XCTAssertEqual(unity, zero, accuracy: 0.000_1)
    }

    func testTopOfFaderIsPlusTenDecibels() {
        let gain = MixerFaderScale.linearGain(forNormalizedPosition: 0)
        XCTAssertEqual(gain, pow(10, MixerFaderScale.maxBoostDB / 20), accuracy: 0.000_1)
        XCTAssertEqual(MixerFaderScale.decibels(forLinearGain: gain), MixerFaderScale.maxBoostDB, accuracy: 0.001)
    }

    func testBottomOfFaderIsMaxAttenuation() {
        let gain = MixerFaderScale.linearGain(forNormalizedPosition: 1)
        XCTAssertEqual(
            MixerFaderScale.decibels(forLinearGain: gain),
            -MixerFaderScale.maxAttenuationDB,
            accuracy: 0.001
        )
    }

    func testEachMarkerRoundTripsThroughGain() {
        for db in MixerFaderScale.markerDecibels {
            let position = MixerFaderScale.normalizedPosition(forDecibels: Double(db))
            let gain = MixerFaderScale.linearGain(forNormalizedPosition: position)
            XCTAssertEqual(MixerFaderScale.decibels(forLinearGain: gain), Double(db), accuracy: 0.01)
        }
    }
}
