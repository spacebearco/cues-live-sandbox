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
    private var stereoPeakLeft: Float = 0
    private var stereoPeakRight: Float = 0
    private var smoothedSquareLeft: Float = 0
    private var smoothedSquareRight: Float = 0
    private var stereoAt: TimeInterval = 0
    private let lock = OSAllocatedUnfairLock()

    func report(_ value: Float) {
        guard value.isFinite, value > 0 else { return }
        lock.withLock {
            peak = max(peak, value)
        }
    }

    /// Render thread: one block's per-side sample peaks and mean squares, for the stereo meters.
    func reportStereo(peakLeft: Float, peakRight: Float, meanSquareLeft: Float, meanSquareRight: Float) {
        guard peakLeft.isFinite, peakRight.isFinite, meanSquareLeft.isFinite, meanSquareRight.isFinite else { return }
        let now = ProcessInfo.processInfo.systemUptime
        lock.withLock {
            let fall = Self.decay(forIdle: Float(max(0, now - stereoAt)))
            stereoPeakLeft = max(stereoPeakLeft * fall, peakLeft)
            stereoPeakRight = max(stereoPeakRight * fall, peakRight)
            smoothedSquareLeft += (max(0, meanSquareLeft) - smoothedSquareLeft) * Self.rmsSmoothing
            smoothedSquareRight += (max(0, meanSquareRight) - smoothedSquareRight) * Self.rmsSmoothing
            stereoAt = now
        }
    }

    /// Left and right peak (instant rise, falling at the meter's release rate) and smoothed
    /// RMS. Everything falls away once the track stops reporting, as a muted or stopped track
    /// does. Reading does not reset anything, so several meters can show the same track.
    func stereoLevels() -> StereoMeterLevels {
        let now = ProcessInfo.processInfo.systemUptime
        return lock.withLock {
            let idle = Float(max(0, now - stereoAt))
            let peakFall = Self.decay(forIdle: idle)
            let rmsFall = idle > 0.1 ? Self.decay(forIdle: idle - 0.1) : 1
            func shown(_ level: Float) -> Float { level < 0.001 ? 0 : level }
            return StereoMeterLevels(
                peakLeft: shown(stereoPeakLeft * peakFall),
                peakRight: shown(stereoPeakRight * peakFall),
                rmsLeft: shown(smoothedSquareLeft.squareRoot() * rmsFall),
                rmsRight: shown(smoothedSquareRight.squareRoot() * rmsFall)
            )
        }
    }

    private static func decay(forIdle seconds: Float) -> Float {
        pow(10, -releaseDbPerSecond * min(seconds, 5) / 20)
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
            stereoPeakLeft = 0
            stereoPeakRight = 0
            smoothedSquareLeft = 0
            smoothedSquareRight = 0
        }
    }
}
