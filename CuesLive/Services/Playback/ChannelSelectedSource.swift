import AVFoundation

/// Plays one channel of a multichannel stem on every output channel, so a stereo file split to
/// mono becomes two mono tracks without rewriting any audio. Everything else passes through.
final class ChannelSelectedSource: StemSampleSource {
    private let base: any StemSampleSource
    let channel: Int

    init(base: any StemSampleSource, channel: Int) {
        self.base = base
        self.channel = max(0, min(channel, base.channelCount - 1))
    }

    var sampleRate: Double { base.sampleRate }
    var channelCount: Int { base.channelCount }
    var frameCount: Int { base.frameCount }
    var audioFormat: AVAudioFormat { base.audioFormat }

    @discardableResult
    func copy(
        channel _: Int,
        startingFrame: Int,
        frameCount: Int,
        into destination: UnsafeMutablePointer<Float>,
        destinationOffset: Int,
        gain: Float
    ) -> Int {
        base.copy(
            channel: channel,
            startingFrame: startingFrame,
            frameCount: frameCount,
            into: destination,
            destinationOffset: destinationOffset,
            gain: gain
        )
    }

    func interpolatedSample(channel _: Int, frame: Double) -> Float {
        base.interpolatedSample(channel: channel, frame: frame)
    }

    func prewarm(aroundSourceFrame frame: Int) { base.prewarm(aroundSourceFrame: frame) }
    func setPinnedRegion(sourceFrames: Range<Int>?) { base.setPinnedRegion(sourceFrames: sourceFrames) }
    func setReaderActive(_ active: Bool) { base.setReaderActive(active) }
    func noteUpcomingJump(toSourceFrame frame: Int?) { base.noteUpcomingJump(toSourceFrame: frame) }
    func preload(fromSourceFrame frame: Int) { base.preload(fromSourceFrame: frame) }
}
