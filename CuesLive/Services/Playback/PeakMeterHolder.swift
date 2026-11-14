import Foundation
import os

final class PeakMeterHolder: @unchecked Sendable {
    /// Fast DAW channel-meter release: 20 dB in 300 ms, so a full-scale peak
    /// falls off a 60 dB scale in about a second. Attack stays immediate.
    private static let releaseDbPerSecond: Float = 20 / 0.3

    /// How much each block moves the RMS average: about 300 ms of memory at the engine's
    /// 2048-frame blocks.
    private static let rmsSmoothing: Float = 0.15

    private var peak: Float = 0
    private var updatedAt: TimeInterval = 0
    private var meanSquare: Float = 0
    private var meanSquareAt: TimeInterval = 0
    private let lock = OSAllocatedUnfairLock()

    func report(_ value: Float) {
        guard value.isFinite, value > 0 else { return }
        lock.withLock {
            peak = max(peak, value)
        }
    }

    /// Render thread: one block's mean square, for the RMS reading.
    func reportMeanSquare(_ value: Float) {
        guard value.isFinite else { return }
        let now = ProcessInfo.processInfo.systemUptime
        lock.withLock {
            meanSquare += (max(0, value) - meanSquare) * Self.rmsSmoothing
            meanSquareAt = now
        }
    }

    /// The smoothed RMS level (linear). It falls away once the track stops reporting, as a
    /// muted or stopped track does.
    func rms() -> Float {
        let now = ProcessInfo.processInfo.systemUptime
        return lock.withLock {
            let idle = Float(max(0, now - meanSquareAt))
            guard idle > 0.1 else { return meanSquare.squareRoot() }
            let decay = pow(10, -Self.releaseDbPerSecond * (idle - 0.1) / 20)
            let level = meanSquare.squareRoot() * decay
            return level < 0.001 ? 0 : level
        }
    }

    func consume() -> Float {
        let now = Date().timeIntervalSinceReferenceDate
        return lock.withLock {
            let shown = peak
            if updatedAt > 0, peak > 0 {
                let dt = Float(min(max(0, now - updatedAt), 0.25))
                if dt > 0 {
                    peak *= pow(10, -Self.releaseDbPerSecond * dt / 20)
                    if peak < 0.001 { peak = 0 }
                }
            }
            updatedAt = now
            return shown
        }
    }

    func reset() {
        lock.withLock {
            peak = 0
            meanSquare = 0
        }
    }
}
