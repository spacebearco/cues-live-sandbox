import Foundation

/// Left and right meter readings, linear (1 is full scale). A mono source reads the same on
/// both sides.
struct StereoMeterLevels: Equatable, Sendable {
    var peakLeft: Float = 0
    var peakRight: Float = 0
    var rmsLeft: Float = 0
    var rmsRight: Float = 0

    static let silent = StereoMeterLevels()

    /// The louder of each reading, for a group's meter across its tracks.
    func merged(with other: StereoMeterLevels) -> StereoMeterLevels {
        StereoMeterLevels(
            peakLeft: max(peakLeft, other.peakLeft),
            peakRight: max(peakRight, other.peakRight),
            rmsLeft: max(rmsLeft, other.rmsLeft),
            rmsRight: max(rmsRight, other.rmsRight)
        )
    }
}
