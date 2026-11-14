import Foundation

/// What the setlist meter shows. Levels are dBFS (true peak in dBTP, loudness in LUFS);
/// `MixMeterReadings.floor` means silence or not measured yet.
struct MixMeterReadings: Equatable, Sendable {
    static let floor: Double = -120

    /// Sample peak with meter ballistics: instant rise, 20 dB/s fall.
    var peakLeft = floor
    var peakRight = floor
    /// Peak-hold lines: stay 1 s, then fall at the same rate.
    var holdLeft = floor
    var holdRight = floor
    /// Highest sample peak and true peak since the last reset.
    var maxPeak = floor
    var truePeak = floor
    /// RMS of both channels over the last 300 ms.
    var rms = floor
    var momentary = floor
    var shortTerm = floor
    var integrated = floor
    /// Seconds of audio the integrated reading covers.
    var measuredSeconds: Double = 0
    /// Some sample reached full scale since the last reset.
    var hasClipped = false
}
