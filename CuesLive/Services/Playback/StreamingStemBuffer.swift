import AVFoundation
import Foundation
import os

/// Disk-streaming sample provider. Instead of decoding an entire stem into RAM,
/// it keeps a bounded sliding window of decoded pages around the playhead. A
/// background timer reads ahead from the file so the real-time render thread
/// only ever reads already-resident pages (never touching disk).
final class StreamingStemBuffer: StemSampleSource, @unchecked Sendable {
    let sampleRate: Double
    let channelCount: Int
    let frameCount: Int
    let audioFormat: AVAudioFormat

    private final class Page {
        let channels: [UnsafeMutablePointer<Float>]
        let validFrames: Int

        init(channelCount: Int, capacity: Int, validFrames: Int) {
            self.validFrames = validFrames
            channels = (0..<channelCount).map { _ in
                let pointer = UnsafeMutablePointer<Float>.allocate(capacity: capacity)
                pointer.initialize(repeating: 0, count: capacity)
                return pointer
            }
        }

        deinit { channels.forEach { $0.deallocate() } }
    }

    private let pageFrames: Int
    private let lookAheadPages: Int
    private let lookBehindPages: Int

    // Resident pages, guarded by `pageLock`. Touched by both render and reader.
    private var pages: [Int: Page] = [:]
    private var pageLock = os_unfair_lock()

    // Latest source frame the render thread asked for, guarded by `centerLock`.
    private var requestedCenterFrame = 0
    // Where the next clip jumps to, also guarded by `centerLock`. Kept resident with the window.
    private var upcomingJumpFrame: Int?
    /// How much audio after a jump target is read in ahead of it.
    private static let jumpLeadSeconds: Double = 1
    private var centerLock = os_unfair_lock()

    // Pages held resident regardless of the playhead, guarded by `pinnedLock`.
    private var pinnedPages: ClosedRange<Int>?
    private var pinnedLock = os_unfair_lock()

    // File + scratch buffer are ONLY ever used on `readerQueue`.
    private let readerQueue = DispatchQueue(label: "StreamingStemBuffer.reader", qos: .userInitiated)
    private static let readerQueueKey = DispatchSpecificKey<UInt8>()
    private let reader: AVAudioFile
    private let readBuffer: AVAudioPCMBuffer
    private let decodeConverter: AVAudioConverter?
    private let decodedScratch: AVAudioPCMBuffer?
    private var timer: DispatchSourceTimer?
    /// When false, the continuous look-ahead timer is not scheduled. One-shot
    /// fills still run from `prewarm` / render requests so seeks and tests work.
    private var isReaderActive = false

    init(
        url: URL,
        pageFrames: Int = 16_384,
        lookAheadSeconds: Double = 6,
        lookBehindSeconds: Double = 1
    ) throws {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard format.channelCount > 0, file.length > 0 else {
            throw DecodedStemBufferError.emptyFile
        }
        guard let scratch = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(pageFrames)
        ) else {
            throw DecodedStemBufferError.unsupportedFormat
        }

        let playbackFormat: AVAudioFormat
        let converter: AVAudioConverter?
        let convertedScratch: AVAudioPCMBuffer?

        if format.commonFormat == .pcmFormatFloat32 && !format.isInterleaved {
            playbackFormat = format
            converter = nil
            convertedScratch = nil
        } else if let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: format.sampleRate,
            channels: format.channelCount,
            interleaved: false
        ),
        let audioConverter = AVAudioConverter(from: format, to: targetFormat),
        let floatScratch = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: AVAudioFrameCount(pageFrames)
        ) {
            playbackFormat = targetFormat
            converter = audioConverter
            convertedScratch = floatScratch
        } else {
            throw DecodedStemBufferError.unsupportedFormat
        }

        reader = file
        readBuffer = scratch
        decodeConverter = converter
        decodedScratch = convertedScratch
        audioFormat = playbackFormat
        sampleRate = format.sampleRate
        channelCount = Int(format.channelCount)
        frameCount = Int(file.length)
        self.pageFrames = pageFrames
        lookAheadPages = max(1, Int((lookAheadSeconds * format.sampleRate / Double(pageFrames)).rounded(.up)))
        lookBehindPages = max(0, Int((lookBehindSeconds * format.sampleRate / Double(pageFrames)).rounded(.up)))
        readerQueue.setSpecific(key: Self.readerQueueKey, value: 1)
    }

    deinit {
        // Never leave a DispatchSource suspended across release — cancel only
        // while it is resumed (or never started).
        if let timer {
            timer.setEventHandler {}
            timer.cancel()
        }
        timer = nil
        // Drain in-flight reader work before releasing page memory. Without this,
        // a teardown during live setlist edits can race the reader queue.
        // Skip sync when deinit already runs on `readerQueue` (last release from
        // an async block) — syncing then aborts.
        if DispatchQueue.getSpecific(key: Self.readerQueueKey) == nil {
            readerQueue.sync { }
        }
        os_unfair_lock_lock(&pageLock)
        pages.removeAll()
        os_unfair_lock_unlock(&pageLock)
    }

    func prewarm(aroundSourceFrame frame: Int) {
        let clamped = max(0, min(frame, max(0, frameCount - 1)))
        os_unfair_lock_lock(&centerLock)
        requestedCenterFrame = clamped
        os_unfair_lock_unlock(&centerLock)
        if DispatchQueue.getSpecific(key: Self.readerQueueKey) != nil {
            fillWindow(around: clamped)
        } else {
            readerQueue.sync { self.fillWindow(around: clamped) }
        }
    }

    func noteUpcomingJump(toSourceFrame frame: Int?) {
        // Never block the audio thread waiting on the reader.
        guard os_unfair_lock_trylock(&centerLock) else { return }
        upcomingJumpFrame = frame.map { max(0, min($0, max(0, frameCount - 1))) }
        os_unfair_lock_unlock(&centerLock)
    }

    func preload(fromSourceFrame frame: Int) {
        let clamped = max(0, min(frame, max(0, frameCount - 1)))
        os_unfair_lock_lock(&centerLock)
        upcomingJumpFrame = clamped
        os_unfair_lock_unlock(&centerLock)
        let pages = jumpPages(from: clamped)
        if DispatchQueue.getSpecific(key: Self.readerQueueKey) != nil {
            fillPages(from: pages.lowerBound, through: pages.upperBound)
        } else {
            readerQueue.sync { self.fillPages(from: pages.lowerBound, through: pages.upperBound) }
        }
    }

    private func jumpPages(from frame: Int) -> ClosedRange<Int> {
        let first = frame / pageFrames
        let lead = Int((Self.jumpLeadSeconds * sampleRate).rounded(.up))
        let last = min(max(0, frameCount - 1), frame + lead) / pageFrames
        return first...max(first, last)
    }

    func setReaderActive(_ active: Bool) {
        // Sync so activation is deterministic before play/seek returns, and so
        // the last strong reference is not released from an async reader block.
        if DispatchQueue.getSpecific(key: Self.readerQueueKey) != nil {
            applyReaderActive(active)
        } else {
            readerQueue.sync { self.applyReaderActive(active) }
        }
    }

    func setPinnedRegion(sourceFrames: Range<Int>?) {
        let range = pageRange(for: sourceFrames)

        os_unfair_lock_lock(&pinnedLock)
        let changed = pinnedPages != range
        pinnedPages = range
        os_unfair_lock_unlock(&pinnedLock)

        guard changed, range != nil else { return }

        // Page in off the caller's thread; nobody should wait on disk to arm a loop.
        readerQueue.async { [weak self] in
            guard let self else { return }
            os_unfair_lock_lock(&self.centerLock)
            let center = self.requestedCenterFrame
            os_unfair_lock_unlock(&self.centerLock)
            self.fillWindow(around: center)
        }
    }

    private func pageRange(for sourceFrames: Range<Int>?) -> ClosedRange<Int>? {
        guard let sourceFrames, !sourceFrames.isEmpty, frameCount > 0 else { return nil }
        guard sourceFrames.lowerBound < frameCount, sourceFrames.upperBound > 0 else { return nil }
        let first = max(0, sourceFrames.lowerBound) / pageFrames
        let last = min(frameCount - 1, sourceFrames.upperBound - 1) / pageFrames
        return first <= last ? first...last : nil
    }

    private func currentPinnedPages() -> ClosedRange<Int>? {
        os_unfair_lock_lock(&pinnedLock)
        defer { os_unfair_lock_unlock(&pinnedLock) }
        return pinnedPages
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

        noteRequested(frame: startingFrame)

        var written = 0
        os_unfair_lock_lock(&pageLock)
        while written < available {
            let globalFrame = startingFrame + written
            let pageIndex = globalFrame / pageFrames
            let offsetInPage = globalFrame % pageFrames
            let spanToPageEnd = min(pageFrames - offsetInPage, available - written)

            // Copy whatever of this page span is resident; the rest stays silent
            // (the destination is pre-zeroed by the caller before mixing).
            if let page = pages[pageIndex], offsetInPage < page.validFrames {
                let copyCount = min(page.validFrames - offsetInPage, spanToPageEnd)
                let source = page.channels[channel].advanced(by: offsetInPage)
                let target = destination.advanced(by: destinationOffset + written)
                if gain == 1 {
                    target.update(from: source, count: copyCount)
                } else {
                    for index in 0..<copyCount {
                        target[index] = source[index] * gain
                    }
                }
            }

            written += spanToPageEnd
        }
        os_unfair_lock_unlock(&pageLock)

        return available
    }

    func interpolatedSample(channel: Int, frame: Double) -> Float {
        guard channel >= 0, channel < channelCount, frameCount > 0, frame >= 0 else { return 0 }

        let baseFrame = frame >= Double(frameCount - 1) ? frameCount - 1 : Int(frame.rounded(.down))
        noteRequested(frame: baseFrame)
        let fraction = Float(frame - Double(baseFrame))

        os_unfair_lock_lock(&pageLock)
        defer { os_unfair_lock_unlock(&pageLock) }
        let sampleA = unlockedSample(channel: channel, frame: baseFrame)
        let sampleB = baseFrame + 1 < frameCount
            ? unlockedSample(channel: channel, frame: baseFrame + 1)
            : sampleA
        return sampleA + (sampleB - sampleA) * fraction
    }

    /// Caller must hold `pageLock`.
    private func unlockedSample(channel: Int, frame: Int) -> Float {
        let pageIndex = frame / pageFrames
        let offsetInPage = frame % pageFrames
        guard let page = pages[pageIndex], offsetInPage < page.validFrames else { return 0 }
        return page.channels[channel][offsetInPage]
    }

    private func noteRequested(frame: Int) {
        // Never block the audio thread waiting on the reader.
        guard os_unfair_lock_trylock(&centerLock) else { return }
        requestedCenterFrame = frame
        os_unfair_lock_unlock(&centerLock)
        // When the continuous timer is off, still schedule a one-shot fill so
        // seeks / loop tests / paused scrubbing page audio in.
        scheduleOneShotFillIfIdle()
    }

    private func scheduleOneShotFillIfIdle() {
        readerQueue.async { [weak self] in
            guard let self, !self.isReaderActive else { return }
            os_unfair_lock_lock(&self.centerLock)
            let center = self.requestedCenterFrame
            os_unfair_lock_unlock(&self.centerLock)
            self.fillWindow(around: center)
        }
    }

    /// Runs on `readerQueue`. Cancel/recreate instead of suspend/resume — releasing
    /// a suspended DispatchSource aborts the process.
    private func applyReaderActive(_ active: Bool) {
        guard isReaderActive != active else { return }
        isReaderActive = active
        if active {
            startReaderTimer()
            os_unfair_lock_lock(&centerLock)
            let center = requestedCenterFrame
            os_unfair_lock_unlock(&centerLock)
            fillWindow(around: center)
        } else {
            stopReaderTimer()
        }
    }

    private func startReaderTimer() {
        stopReaderTimer()
        let source = DispatchSource.makeTimerSource(queue: readerQueue)
        source.schedule(deadline: .now(), repeating: .milliseconds(40), leeway: .milliseconds(10))
        source.setEventHandler { [weak self] in
            guard let self, self.isReaderActive else { return }
            os_unfair_lock_lock(&self.centerLock)
            let center = self.requestedCenterFrame
            os_unfair_lock_unlock(&self.centerLock)
            self.fillWindow(around: center)
        }
        timer = source
        source.resume()
    }

    private func stopReaderTimer() {
        guard let timer else { return }
        timer.setEventHandler {}
        timer.cancel()
        self.timer = nil
    }

    /// Runs on `readerQueue`. Evicts out-of-window pages and decodes missing ones.
    private func fillWindow(around centerFrame: Int) {
        let centerPage = centerFrame / pageFrames
        let lowest = max(0, centerPage - lookBehindPages)
        let highest = centerPage + lookAheadPages
        let pinned = currentPinnedPages()
        os_unfair_lock_lock(&centerLock)
        let jump = upcomingJumpFrame.map(jumpPages(from:))
        os_unfair_lock_unlock(&centerLock)

        os_unfair_lock_lock(&pageLock)
        let residentIndices = Array(pages.keys)
        os_unfair_lock_unlock(&pageLock)

        for index in residentIndices
        where (index < lowest || index > highest) && pinned?.contains(index) != true && jump?.contains(index) != true {
            os_unfair_lock_lock(&pageLock)
            pages[index] = nil
            os_unfair_lock_unlock(&pageLock)
        }

        // Sliding window first: it feeds the frames about to be rendered.
        fillPages(from: lowest, through: highest)

        if let jump {
            fillPages(from: jump.lowerBound, through: jump.upperBound)
        }

        if let pinned {
            fillPages(from: pinned.lowerBound, through: pinned.upperBound)
        }
    }

    /// Runs on `readerQueue`. Decodes any missing page in the inclusive range.
    private func fillPages(from lowest: Int, through highest: Int) {
        var index = max(0, lowest)
        while index <= highest {
            guard index * pageFrames < frameCount else { break }

            os_unfair_lock_lock(&pageLock)
            let alreadyResident = pages[index] != nil
            os_unfair_lock_unlock(&pageLock)

            if !alreadyResident, let page = decodePage(index) {
                os_unfair_lock_lock(&pageLock)
                pages[index] = page
                os_unfair_lock_unlock(&pageLock)
            }
            index += 1
        }
    }

    /// Runs on `readerQueue`. Reads one page worth of frames from disk.
    private func decodePage(_ index: Int) -> Page? {
        let startFrame = index * pageFrames
        guard startFrame < frameCount else { return nil }
        let framesToRead = min(pageFrames, frameCount - startFrame)

        do {
            reader.framePosition = AVAudioFramePosition(startFrame)
            readBuffer.frameLength = 0
            try reader.read(into: readBuffer, frameCount: AVAudioFrameCount(framesToRead))
        } catch {
            return nil
        }

        let framesRead = Int(readBuffer.frameLength)
        guard framesRead > 0 else { return nil }

        let channelData: UnsafePointer<UnsafeMutablePointer<Float>>
        let validFrames: Int

        if let decodeConverter, let decodedScratch {
            decodeConverter.reset()
            decodedScratch.frameLength = 0
            var conversionError: NSError?
            var didProvideInput = false
            let inputBuffer = readBuffer
            let status = decodeConverter.convert(to: decodedScratch, error: &conversionError) { _, outStatus in
                if didProvideInput {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                didProvideInput = true
                outStatus.pointee = .haveData
                return inputBuffer
            }
            guard status != .error,
                  decodedScratch.frameLength > 0,
                  let convertedChannels = decodedScratch.floatChannelData else {
                return nil
            }
            channelData = convertedChannels
            validFrames = Int(decodedScratch.frameLength)
        } else if let directChannels = readBuffer.floatChannelData {
            channelData = directChannels
            validFrames = framesRead
        } else {
            return nil
        }

        let page = Page(channelCount: channelCount, capacity: pageFrames, validFrames: validFrames)
        for channel in 0..<channelCount {
            page.channels[channel].update(from: channelData[channel], count: validFrames)
        }
        return page
    }
}
