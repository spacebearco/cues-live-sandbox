import AVFoundation

/// A low-pass filter that closes as the Fade button fades a song out, so the fade sounds like a
/// filter sweep rather than only a level change. `closure` 0 is fully open (the filter is
/// bypassed), 1 is closed down to `minimumHz`; the cutoff moves exponentially between them, as
/// the ear hears pitch. Runs on the render thread: storage is allocated once, nothing locks.
final class LowPassSweep {
    static let maximumHz = 20_000.0
    static let minimumHz = 150.0
    /// How far `closure` may move per block, so a jump in the setting never clicks.
    private static let maximumStepPerBlock = 0.05

    private let sampleRate: Double
    private let channelCount: Int
    /// Two transposed-direct-form-II memories per channel.
    private let memory: UnsafeMutablePointer<Double>
    private var current = 0.0

    init(sampleRate: Double, channelCount: Int) {
        self.sampleRate = sampleRate > 0 ? sampleRate : 48_000
        self.channelCount = max(1, channelCount)
        memory = .allocate(capacity: self.channelCount * 2)
        memory.initialize(repeating: 0, count: self.channelCount * 2)
    }

    deinit {
        memory.deallocate()
    }

    /// The cutoff for a closure amount.
    static func cutoffHz(forClosure closure: Double) -> Double {
        let amount = min(max(closure, 0), 1)
        return maximumHz * pow(minimumHz / maximumHz, amount)
    }

    /// Filters `frameCount` frames in place, moving toward `closure`.
    func process(_ buffers: UnsafeMutableAudioBufferListPointer, frameCount: Int, closure target: Double) {
        let clampedTarget = min(max(target, 0), 1)
        let step = min(max(clampedTarget - current, -Self.maximumStepPerBlock), Self.maximumStepPerBlock)
        current += step
        guard current > 0.0005 else {
            // Open: bypass, and forget old state so a later sweep starts clean.
            if current != 0 || memory[0] != 0 || memory[1] != 0 {
                current = 0
                memory.update(repeating: 0, count: channelCount * 2)
            }
            return
        }

        let cutoff = min(Self.cutoffHz(forClosure: current), sampleRate * 0.45)
        // RBJ low-pass, Q = 1/sqrt(2).
        let omega = 2 * Double.pi * cutoff / sampleRate
        let alpha = sin(omega) / (2 * 0.707_106_781)
        let cosine = cos(omega)
        let a0 = 1 + alpha
        let b0 = (1 - cosine) / 2 / a0
        let b1 = (1 - cosine) / a0
        let b2 = b0
        let a1 = -2 * cosine / a0
        let a2 = (1 - alpha) / a0

        for (index, buffer) in buffers.enumerated() where index < channelCount {
            guard let samples = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
            var z1 = memory[index * 2]
            var z2 = memory[index * 2 + 1]
            for frame in 0..<frameCount {
                let x = Double(samples[frame])
                let y = b0 * x + z1
                z1 = b1 * x - a1 * y + z2
                z2 = b2 * x - a2 * y
                samples[frame] = Float(y)
            }
            if !(z1.isFinite && z2.isFinite) {
                z1 = 0
                z2 = 0
            }
            memory[index * 2] = z1
            memory[index * 2 + 1] = z2
        }
    }
}
