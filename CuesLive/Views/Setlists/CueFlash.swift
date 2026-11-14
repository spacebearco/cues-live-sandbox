import Foundation

/// The blink of a cued section. Every view that shows it reads the phase from the clock, so
/// the waveform band and the section row blink together and nothing above them has to
/// re-render to make them blink.
enum CueFlash {
    static let interval: TimeInterval = 0.35

    /// True on the bright half of the blink.
    static var isBright: Bool {
        Int(Date.timeIntervalSinceReferenceDate / interval) % 2 == 0
    }
}
