import AVFoundation
import Foundation
import os

enum DecodedStemBufferError: Error {
    case unsupportedFormat
    case conversionFailed
    case emptyFile
}

/// Real-time sample provider for one track. Both the fully-in-memory
/// `DecodedStemBuffer` and the disk-streaming `StreamingStemBuffer` conform,
/// so the render path can read samples without knowing the backing storage.
protocol StemSampleSource: AnyObject, Sendable {
    var sampleRate: Double { get }
    var channelCount: Int { get }
    var frameCount: Int { get }
    var audioFormat: AVAudioFormat { get }

    @discardableResult
    func copy(
        channel: Int,
        startingFrame: Int,
        frameCount: Int,
        into destination: UnsafeMutablePointer<Float>,
        destinationOffset: Int,
        gain: Float
    ) -> Int

    func interpolatedSample(channel: Int, frame: Double) -> Float

    /// Hint that playback is about to read near `frame`; streaming sources use
    /// this to warm their look-ahead window. In-memory sources ignore it.
    func prewarm(aroundSourceFrame frame: Int)

    /// Keeps `sourceFrames` resident no matter where the playhead is. Streaming
    /// sources evict pages behind the playhead, so a loop restart would otherwise
    /// read silence from the loop head. In-memory sources ignore it.
    func setPinnedRegion(sourceFrames: Range<Int>?)

    /// Starts or stops background look-ahead reading. Streaming sources pause
    /// their reader timer when inactive so idle songs do not burn CPU/disk.
    func setReaderActive(_ active: Bool)

    /// Render thread: the next clip jumps to `frame` soon. Streaming sources read it in ahead
    /// and keep it until the jump. `nil` when no jump is coming. In-memory sources ignore it.
    func noteUpcomingJump(toSourceFrame frame: Int?)

    /// Reads the audio from `frame` on in before an edit switches playback to it, without
    /// disturbing what is playing now. In-memory sources ignore it.
    func preload(fromSourceFrame frame: Int)
}

extension StemSampleSource {
    func prewarm(aroundSourceFrame frame: Int) {}
    func noteUpcomingJump(toSourceFrame frame: Int?) {}
    func preload(fromSourceFrame frame: Int) {}
    func setPinnedRegion(sourceFrames: Range<Int>?) {}
    func setReaderActive(_ active: Bool) {}
}

/// Float32 PCM decoded once at load time for real-time memory playback.
final class DecodedStemBuffer: StemSampleSource, @unchecked Sendable {
    static let engineSampleRate: Double = 48_000

    let sampleRate: Double
    let channelCount: Int
    let frameCount: Int
    let audioFormat: AVAudioFormat

    private let channels: [UnsafeMutablePointer<Float>]

    private init(
        sampleRate: Double,
        channelCount: Int,
        frameCount: Int,
        audioFormat: AVAudioFormat,
        channels: [UnsafeMutablePointer<Float>]
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameCount = frameCount
        self.audioFormat = audioFormat
        self.channels = channels
    }

    deinit {
        for channel in channels {
            channel.deallocate()
        }
    }

    static func decode(
        from data: Data,
        targetSampleRate: Double = engineSampleRate
    ) throws -> DecodedStemBuffer {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
            .appendingPathExtension("wav")
        try data.write(to: tempURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        return try decode(from: tempURL, targetSampleRate: targetSampleRate)
    }

    static func decode(
        from url: URL,
        targetSampleRate: Double = engineSampleRate
    ) throws -> DecodedStemBuffer {
        let file = try AVAudioFile(forReading: url)
        let sourceFormat = file.processingFormat
        let channelCount = Int(sourceFormat.channelCount)
        guard channelCount > 0 else { throw DecodedStemBufferError.unsupportedFormat }

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: AVAudioChannelCount(channelCount),
            interleaved: false
        ) else {
            throw DecodedStemBufferError.unsupportedFormat
        }

        var channelArrays = Array(repeating: ContiguousArray<Float>(), count: channelCount)

        let canReadDirectly =
            sourceFormat.sampleRate == targetSampleRate
            && sourceFormat.commonFormat == .pcmFormatFloat32
            && !sourceFormat.isInterleaved

        if canReadDirectly {
            try readDirectly(from: file, channelCount: channelCount, into: &channelArrays)
        } else {
            try convertIntoMemory(
                from: file,
                sourceFormat: sourceFormat,
                targetFormat: targetFormat,
                channelCount: channelCount,
                into: &channelArrays
            )
        }

        guard let firstChannel = channelArrays.first, !firstChannel.isEmpty else {
            throw DecodedStemBufferError.emptyFile
        }

        let frameCount = firstChannel.count
        let channelPointers = channelArrays.map { array -> UnsafeMutablePointer<Float> in
            let pointer = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
            array.withUnsafeBufferPointer { buffer in
                pointer.initialize(from: buffer.baseAddress!, count: frameCount)
            }
            return pointer
        }

        return DecodedStemBuffer(
            sampleRate: targetSampleRate,
            channelCount: channelCount,
            frameCount: frameCount,
            audioFormat: targetFormat,
            channels: channelPointers
        )
    }

    func channelPointer(_ channel: Int) -> UnsafePointer<Float> {
        UnsafePointer(channels[channel])
    }

    func mutableChannelPointer(_ channel: Int) -> UnsafeMutablePointer<Float> {
        channels[channel]
    }

    @discardableResult
    func copy(
        channel: Int,
        startingFrame: Int,
        frameCount requestedFrames: Int,
        into destination: UnsafeMutablePointer<Float>,
        destinationOffset: Int,
        gain: Float
    ) -> Int {
        guard channel >= 0, channel < channelCount else { return 0 }
        guard startingFrame >= 0, startingFrame < frameCount else { return 0 }

        let available = min(requestedFrames, frameCount - startingFrame)
        guard available > 0 else { return 0 }

        let source = channels[channel].advanced(by: startingFrame)
        let destinationPointer = destination.advanced(by: destinationOffset)

        if gain == 1 {
            destinationPointer.update(from: source, count: available)
        } else {
            for index in 0..<available {
                destinationPointer[index] = source[index] * gain
            }
        }

        return available
    }

    func interpolatedSample(channel: Int, frame: Double) -> Float {
        guard channel >= 0, channel < channelCount, frameCount > 0 else { return 0 }
        guard frame >= 0 else { return 0 }

        if frame >= Double(frameCount - 1) {
            return channels[channel][frameCount - 1]
        }

        let index = Int(floor(frame))
        let fraction = Float(frame - Double(index))
        let sampleA = channels[channel][index]
        let sampleB = channels[channel][index + 1]
        return sampleA + (sampleB - sampleA) * fraction
    }

    /// Converts a PCM buffer to a mono engine-rate stem, downmixing and resampling as needed.
    static func monoStem(
        from buffer: AVAudioPCMBuffer,
        targetSampleRate: Double = engineSampleRate
    ) throws -> DecodedStemBuffer {
        guard buffer.frameLength > 0 else { throw DecodedStemBufferError.emptyFile }

        let sourceFormat = buffer.format
        guard let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw DecodedStemBufferError.unsupportedFormat
        }

        let converted: AVAudioPCMBuffer
        if sourceFormat.sampleRate == monoFormat.sampleRate,
           sourceFormat.channelCount == 1,
           sourceFormat.commonFormat == .pcmFormatFloat32,
           !sourceFormat.isInterleaved {
            converted = buffer
        } else {
            guard let converter = AVAudioConverter(from: sourceFormat, to: monoFormat) else {
                throw DecodedStemBufferError.conversionFailed
            }
            let ratio = monoFormat.sampleRate / sourceFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
            guard let output = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: capacity) else {
                throw DecodedStemBufferError.conversionFailed
            }

            var error: NSError?
            var consumedInput = false
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                if consumedInput {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                consumedInput = true
                outStatus.pointee = .haveData
                return buffer
            }
            converter.convert(to: output, error: &error, withInputFrom: inputBlock)
            if error != nil {
                throw DecodedStemBufferError.conversionFailed
            }
            converted = output
        }

        let frameCount = Int(converted.frameLength)
        guard frameCount > 0, let source = converted.floatChannelData?[0] else {
            throw DecodedStemBufferError.emptyFile
        }

        // If conversion kept multiple channels (shouldn't with monoFormat), downmix manually.
        let channelCount = Int(converted.format.channelCount)
        let pointer = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        if channelCount <= 1 {
            pointer.initialize(from: source, count: frameCount)
        } else {
            pointer.initialize(repeating: 0, count: frameCount)
            let scale = 1 / Float(channelCount)
            for channel in 0..<channelCount {
                guard let channelData = converted.floatChannelData?[channel] else { continue }
                for frame in 0..<frameCount {
                    pointer[frame] += channelData[frame] * scale
                }
            }
        }

        return DecodedStemBuffer(
            sampleRate: targetSampleRate,
            channelCount: 1,
            frameCount: frameCount,
            audioFormat: monoFormat,
            channels: [pointer]
        )
    }

    static func silent(
        frameCount: Int,
        sampleRate: Double = engineSampleRate,
        channelCount: Int = 1
    ) throws -> DecodedStemBuffer {
        guard frameCount > 0, channelCount > 0 else {
            throw DecodedStemBufferError.emptyFile
        }
        guard let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channelCount),
            interleaved: false
        ) else {
            throw DecodedStemBufferError.unsupportedFormat
        }

        var channelPointers: [UnsafeMutablePointer<Float>] = []
        channelPointers.reserveCapacity(channelCount)
        for _ in 0..<channelCount {
            let pointer = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
            pointer.initialize(repeating: 0, count: frameCount)
            channelPointers.append(pointer)
        }

        return DecodedStemBuffer(
            sampleRate: sampleRate,
            channelCount: channelCount,
            frameCount: frameCount,
            audioFormat: audioFormat,
            channels: channelPointers
        )
    }

    /// Exposes a channel's PCM for in-place synthesis (e.g. LTC).
    func withMutableSamples(channel: Int, _ body: (UnsafeMutablePointer<Float>, Int) -> Void) {
        guard channel >= 0, channel < channelCount else { return }
        body(channels[channel], frameCount)
    }

    private static func readDirectly(
        from file: AVAudioFile,
        channelCount: Int,
        into channelArrays: inout [ContiguousArray<Float>]
    ) throws {
        let chunkFrames: AVAudioFrameCount = 8_192
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: chunkFrames
        ), let channelData = buffer.floatChannelData else {
            throw DecodedStemBufferError.unsupportedFormat
        }

        file.framePosition = 0
        while file.framePosition < file.length {
            let remaining = AVAudioFrameCount(file.length - file.framePosition)
            let readCount = min(chunkFrames, remaining)
            buffer.frameLength = 0
            try file.read(into: buffer, frameCount: readCount)

            let framesRead = Int(buffer.frameLength)
            guard framesRead > 0 else { break }

            for channel in 0..<channelCount {
                channelArrays[channel].append(contentsOf: UnsafeBufferPointer(
                    start: channelData[channel],
                    count: framesRead
                ))
            }
        }
    }

    private static func convertIntoMemory(
        from file: AVAudioFile,
        sourceFormat: AVAudioFormat,
        targetFormat: AVAudioFormat,
        channelCount: Int,
        into channelArrays: inout [ContiguousArray<Float>]
    ) throws {
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw DecodedStemBufferError.conversionFailed
        }

        let inputChunkFrames: AVAudioFrameCount = 8_192
        let outputChunkFrames: AVAudioFrameCount = 8_192

        guard let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: inputChunkFrames
        ), let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputChunkFrames
        ), let outputChannels = outputBuffer.floatChannelData else {
            throw DecodedStemBufferError.conversionFailed
        }

        file.framePosition = 0
        var inputFinished = false

        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if inputFinished {
                outStatus.pointee = .noDataNow
                return nil
            }

            let remaining = AVAudioFrameCount(file.length - file.framePosition)
            if remaining == 0 {
                outStatus.pointee = .endOfStream
                inputFinished = true
                return nil
            }

            let readCount = min(inputChunkFrames, remaining)
            inputBuffer.frameLength = 0

            do {
                try file.read(into: inputBuffer, frameCount: readCount)
            } catch {
                outStatus.pointee = .endOfStream
                inputFinished = true
                return nil
            }

            if inputBuffer.frameLength == 0 {
                outStatus.pointee = .endOfStream
                inputFinished = true
                return nil
            }

            outStatus.pointee = .haveData
            return inputBuffer
        }

        while true {
            outputBuffer.frameLength = 0
            var conversionError: NSError?
            let status = converter.convert(
                to: outputBuffer,
                error: &conversionError,
                withInputFrom: inputBlock
            )

            if let conversionError {
                throw conversionError
            }

            let framesConverted = Int(outputBuffer.frameLength)
            if framesConverted > 0 {
                for channel in 0..<channelCount {
                    channelArrays[channel].append(contentsOf: UnsafeBufferPointer(
                        start: outputChannels[channel],
                        count: framesConverted
                    ))
                }
            }

            if status == .endOfStream, framesConverted == 0 {
                break
            }
        }
    }
}
