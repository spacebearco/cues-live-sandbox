import Foundation

/// Measures a stereo mix the way SpaceBear MixReview does: ITU-R BS.1770 K-weighted loudness
/// (momentary, short-term, gated integrated), 4x oversampled true peak, sample peak with
/// ballistics, and RMS. Feed blocks with `process`, then call `readings(at:)` about 30 times a second.
struct MixLoudnessAnalyzer {
    private struct Biquad {
        var b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    }

    /// Transposed direct form II memory for one biquad on one channel.
    private struct FilterMemory {
        var z1 = 0.0, z2 = 0.0

        mutating func run(_ filter: Biquad, _ x: Double) -> Double {
            let y = filter.b0 * x + z1
            z1 = filter.b1 * x - filter.a1 * y + z2
            z2 = filter.b2 * x - filter.a2 * y
            return y
        }

        var isFinite: Bool { z1.isFinite && z2.isFinite }
    }

    private struct Slice {
        var weightedEnergy: Double
        var squares: Double
        var frames: Int
    }

    private static let truePeakTaps = 12
    private static let gateBinCount = 800
    /// Peak ballistics: 20 dB per second fall, 1 s hold.
    private static let fallPerSecond = 20.0
    private static let holdSeconds = 1.0

    let sampleRate: Double
    private let shelf: Biquad
    private let highPass: Biquad
    private var shelfLeft = FilterMemory(), shelfRight = FilterMemory()
    private var highPassLeft = FilterMemory(), highPassRight = FilterMemory()

    private let truePeakCoefficients: [Float]
    /// The last 12 samples of each channel, stored twice so one window is always contiguous.
    private var historyLeft: [Float]
    private var historyRight: [Float]
    private var historyPosition = 0

    private let sliceFrames: Int
    private var pending = Slice(weightedEnergy: 0, squares: 0, frames: 0)
    private var slices: [Slice] = []
    private var gateEnergy: [Double]
    private var gateCounts: [Int]

    private var blockPeakLeft: Float = 0
    private var blockPeakRight: Float = 0
    private var blockTruePeak: Float = 0
    private var blockClipped = false
    private var holdUntilLeft: TimeInterval = 0
    private var holdUntilRight: TimeInterval = 0
    private var lastReadingTime: TimeInterval?
    private var current = MixMeterReadings()

    init(sampleRate: Double) {
        let rate = sampleRate > 0 ? sampleRate : 48_000
        self.sampleRate = rate
        (shelf, highPass) = Self.kWeighting(sampleRate: rate)
        truePeakCoefficients = Self.truePeakFilter()
        historyLeft = Array(repeating: 0, count: Self.truePeakTaps * 2)
        historyRight = Array(repeating: 0, count: Self.truePeakTaps * 2)
        sliceFrames = max(1, Int(rate / 10))
        gateEnergy = Array(repeating: 0, count: Self.gateBinCount)
        gateCounts = Array(repeating: 0, count: Self.gateBinCount)
    }

    /// BS.1770 stage 1 (high shelf, +4 dB above about 1.7 kHz) and stage 2 (high-pass at about
    /// 38 Hz), with libebur128's formulas so they hold at any sample rate.
    private static func kWeighting(sampleRate fs: Double) -> (Biquad, Biquad) {
        let gain = 3.999843853973347, shelfQ = 0.7071752369554196, shelfFrequency = 1681.974450955533
        var k = tan(Double.pi * shelfFrequency / fs)
        let vh = pow(10, gain / 20), vb = pow(vh, 0.4996667741545416)
        var a0 = 1 + k / shelfQ + k * k
        let shelf = Biquad(
            b0: (vh + vb * k / shelfQ + k * k) / a0,
            b1: 2 * (k * k - vh) / a0,
            b2: (vh - vb * k / shelfQ + k * k) / a0,
            a1: 2 * (k * k - 1) / a0,
            a2: (1 - k / shelfQ + k * k) / a0
        )
        let passQ = 0.5003270373238773, passFrequency = 38.13547087602444
        k = tan(Double.pi * passFrequency / fs)
        a0 = 1 + k / passQ + k * k
        let highPass = Biquad(b0: 1, b1: -2, b2: 1, a1: 2 * (k * k - 1) / a0, a2: (1 - k / passQ + k * k) / a0)
        return (shelf, highPass)
    }

    /// 48-tap Hann-windowed sinc at a quarter of the oversampled rate, split into 4 phases of 12.
    private static func truePeakFilter() -> [Float] {
        let taps = 4 * truePeakTaps
        var coefficients = [Float](repeating: 0, count: taps)
        for j in 0..<taps {
            let m = Double(j) - Double(taps - 1) / 2
            let x = m * Double.pi / 4
            let window = 0.5 * (1 - cos(2 * Double.pi * Double(j) / Double(taps - 1)))
            coefficients[(j % 4) * truePeakTaps + j / 4] = Float((abs(x) < 1e-9 ? 1 : sin(x) / x) * window)
        }
        return coefficients
    }

    /// Measures `count` frames of the mix.
    mutating func process(left: UnsafePointer<Float>, right: UnsafePointer<Float>, count: Int) {
        for frame in 0..<count {
            let l = left[frame], r = right[frame]
            let absLeft = abs(l), absRight = abs(r)
            if absLeft > blockPeakLeft { blockPeakLeft = absLeft }
            if absRight > blockPeakRight { blockPeakRight = absRight }
            if absLeft >= 1 || absRight >= 1 { blockClipped = true }

            let weightedLeft = highPassLeft.run(highPass, shelfLeft.run(shelf, Double(l)))
            let weightedRight = highPassRight.run(highPass, shelfRight.run(shelf, Double(r)))
            pending.weightedEnergy += weightedLeft * weightedLeft + weightedRight * weightedRight
            pending.squares += Double(l) * Double(l) + Double(r) * Double(r)
            pending.frames += 1

            measureTruePeak(left: l, right: r)
            if pending.frames >= sliceFrames {
                closeSlice()
            }
        }
        // A NaN or infinity would poison the filters for good; start them over.
        if !(shelfLeft.isFinite && shelfRight.isFinite && highPassLeft.isFinite && highPassRight.isFinite) {
            shelfLeft = FilterMemory(); shelfRight = FilterMemory()
            highPassLeft = FilterMemory(); highPassRight = FilterMemory()
            pending = Slice(weightedEnergy: 0, squares: 0, frames: 0)
        }
    }

    private mutating func measureTruePeak(left: Float, right: Float) {
        let taps = Self.truePeakTaps
        historyLeft[historyPosition] = left
        historyLeft[historyPosition + taps] = left
        historyRight[historyPosition] = right
        historyRight[historyPosition + taps] = right
        // Oldest first: window[0] ... window[11] is this sample.
        let start = historyPosition + 1
        var peak = blockTruePeak
        for phase in 0..<4 {
            let base = phase * taps
            var sumLeft: Float = 0, sumRight: Float = 0
            for tap in 0..<taps {
                let coefficient = truePeakCoefficients[base + tap]
                sumLeft += coefficient * historyLeft[start + taps - 1 - tap]
                sumRight += coefficient * historyRight[start + taps - 1 - tap]
            }
            peak = max(peak, abs(sumLeft), abs(sumRight))
        }
        if peak.isFinite { blockTruePeak = peak }
        historyPosition = historyPosition + 1 == taps ? 0 : historyPosition + 1
    }

    /// Closes a 100 ms slice. Every slice also ends a 400 ms gating block (75% overlap).
    private mutating func closeSlice() {
        slices.append(pending)
        pending = Slice(weightedEnergy: 0, squares: 0, frames: 0)
        if slices.count > 30 {
            slices.removeFirst(slices.count - 30)
        }
        current.measuredSeconds += 0.1
        current.momentary = loudness(ofLast: 4)
        current.shortTerm = loudness(ofLast: 30)
        current.rms = rms(ofLast: 3)

        guard slices.count >= 4 else { return }
        let block = current.momentary
        if block > -70 {
            let bin = min(Self.gateBinCount - 1, Int((block + 70) * 10))
            gateEnergy[bin] += pow(10, (block + 0.691) / 10)
            gateCounts[bin] += 1
        }
        let ungated = gatedMean(fromBin: 0)
        if ungated > MixMeterReadings.floor {
            current.integrated = gatedMean(fromBin: Int(((ungated - 10) + 70) * 10) + 1)
        }
    }

    private func loudness(ofLast count: Int) -> Double {
        let recent = slices.suffix(count)
        let frames = recent.reduce(0) { $0 + $1.frames }
        guard frames > 0 else { return MixMeterReadings.floor }
        let meanSquare = recent.reduce(0.0) { $0 + $1.weightedEnergy } / Double(frames)
        return meanSquare > 0 ? max(MixMeterReadings.floor, -0.691 + 10 * log10(meanSquare)) : MixMeterReadings.floor
    }

    private func rms(ofLast count: Int) -> Double {
        let recent = slices.suffix(count)
        let frames = recent.reduce(0) { $0 + $1.frames }
        guard frames > 0 else { return MixMeterReadings.floor }
        let meanSquare = recent.reduce(0.0) { $0 + $1.squares } / Double(frames * 2)
        return meanSquare > 0 ? max(MixMeterReadings.floor, 10 * log10(meanSquare)) : MixMeterReadings.floor
    }

    /// Mean loudness of the gating blocks from `fromBin` up (0.1 LU bins from -70 LUFS).
    private func gatedMean(fromBin: Int) -> Double {
        var energy = 0.0, count = 0
        for bin in min(Self.gateBinCount, max(0, fromBin))..<Self.gateBinCount {
            energy += gateEnergy[bin]
            count += gateCounts[bin]
        }
        return count > 0 ? -0.691 + 10 * log10(energy / Double(count)) : MixMeterReadings.floor
    }

    /// The meter as of `now` (seconds on any steady clock). Peaks cover the audio since the last call.
    mutating func readings(at now: TimeInterval) -> MixMeterReadings {
        let elapsed = lastReadingTime.map { min(max(0, now - $0), 0.25) } ?? 0
        lastReadingTime = now
        let fall = Self.fallPerSecond * elapsed
        let left = Self.decibels(blockPeakLeft), right = Self.decibels(blockPeakRight)

        current.peakLeft = max(left, max(MixMeterReadings.floor, current.peakLeft - fall))
        current.peakRight = max(right, max(MixMeterReadings.floor, current.peakRight - fall))
        if left >= current.holdLeft {
            current.holdLeft = left
            holdUntilLeft = now + Self.holdSeconds
        } else if now > holdUntilLeft {
            current.holdLeft = max(current.peakLeft, current.holdLeft - fall)
        }
        if right >= current.holdRight {
            current.holdRight = right
            holdUntilRight = now + Self.holdSeconds
        } else if now > holdUntilRight {
            current.holdRight = max(current.peakRight, current.holdRight - fall)
        }
        current.maxPeak = max(current.maxPeak, left, right)
        current.truePeak = max(current.truePeak, Self.decibels(blockTruePeak))
        current.hasClipped = current.hasClipped || blockClipped

        blockPeakLeft = 0
        blockPeakRight = 0
        blockTruePeak = 0
        blockClipped = false
        return current
    }

    /// Starts the integrated reading, the maximums and the clip light over. Peaks keep falling.
    mutating func resetMeasurement() {
        slices = []
        pending = Slice(weightedEnergy: 0, squares: 0, frames: 0)
        gateEnergy = Array(repeating: 0, count: Self.gateBinCount)
        gateCounts = Array(repeating: 0, count: Self.gateBinCount)
        current.momentary = MixMeterReadings.floor
        current.shortTerm = MixMeterReadings.floor
        current.integrated = MixMeterReadings.floor
        current.rms = MixMeterReadings.floor
        current.measuredSeconds = 0
        current.maxPeak = MixMeterReadings.floor
        current.truePeak = MixMeterReadings.floor
        current.hasClipped = false
    }

    private static func decibels(_ amplitude: Float) -> Double {
        amplitude > 0 ? max(MixMeterReadings.floor, 20 * log10(Double(amplitude))) : MixMeterReadings.floor
    }
}
