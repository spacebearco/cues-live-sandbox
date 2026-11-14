import AVFoundation

/// Fades a track across an arrangement change during playback. The last block on the old
/// arrangement fades out and the new one fades back in, so an edit made while the song plays
/// never clicks. Runs on the render thread: no allocation, no locks.
struct ArrangementSwapFade {
    private let fadeInFrames: Int
    private var fadeInRemaining = 0

    init(sampleRate: Double, fadeInSeconds: Double = 0.01) {
        fadeInFrames = max(1, Int(sampleRate * fadeInSeconds))
    }

    /// Ramps the whole block from full level to silence and arms the fade-in.
    mutating func fadeOut(_ buffers: UnsafeMutableAudioBufferListPointer, frameCount: Int) {
        guard frameCount > 0 else { return }
        let step = 1 / Float(frameCount)
        for buffer in buffers {
            guard let samples = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
            for frame in 0..<frameCount {
                samples[frame] *= 1 - Float(frame + 1) * step
            }
        }
        fadeInRemaining = fadeInFrames
    }

    /// Continues the fade-in after a swap; does nothing once it has finished.
    mutating func fadeIn(_ buffers: UnsafeMutableAudioBufferListPointer, frameCount: Int) {
        guard fadeInRemaining > 0 else { return }
        let done = fadeInFrames - fadeInRemaining
        let total = Float(fadeInFrames)
        for buffer in buffers {
            guard let samples = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
            for frame in 0..<frameCount {
                samples[frame] *= min(1, Float(done + frame) / total)
            }
        }
        fadeInRemaining = max(0, fadeInRemaining - frameCount)
    }

    /// Drops any fade in progress, for a swap that lands while the track is silent.
    mutating func cancel() {
        fadeInRemaining = 0
    }
}
