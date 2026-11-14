import AVFoundation
import Foundation
import os

/// A stereo ring the music tracks add their post-fader output into, so the setlist meter can
/// read the mix without click, cues or timecode, whatever outputs those are routed to.
///
/// Each track owns a slot with its own frame cursor. All tracks render the same frames each
/// cycle, so frames below the slowest included cursor hold the whole mix. Render-side writes
/// are plain memory and never allocate or lock (one engine renders on one thread); the reader
/// and `reset` share a lock and run only while the engine is stopped or on the reader's side.
final class MixMeterBus: @unchecked Sendable {
    static let capacity = 1 << 16
    static let maxSlots = 256
    private static let mask = Int64(capacity - 1)

    private let left: UnsafeMutablePointer<Float>
    private let right: UnsafeMutablePointer<Float>
    private let cursors: UnsafeMutablePointer<Int64>
    /// 0 unused, 1 renders but is not measured (click, cues, timecode), 2 measured.
    private let slotStates: UnsafeMutablePointer<Int32>
    private var readPosition: Int64 = 0
    private var slotCount = 0
    private var rate: Double = 0
    private var slotByTrackID: [UUID: Int] = [:]
    private var excludedGroups: Set<UUID> = []
    private var resetCount = 0
    private let readerLock = OSAllocatedUnfairLock()

    init() {
        left = .allocate(capacity: Self.capacity)
        left.initialize(repeating: 0, count: Self.capacity)
        right = .allocate(capacity: Self.capacity)
        right.initialize(repeating: 0, count: Self.capacity)
        cursors = .allocate(capacity: Self.maxSlots)
        cursors.initialize(repeating: 0, count: Self.maxSlots)
        slotStates = .allocate(capacity: Self.maxSlots)
        slotStates.initialize(repeating: 0, count: Self.maxSlots)
    }

    deinit {
        left.deallocate()
        right.deallocate()
        cursors.deallocate()
        slotStates.deallocate()
    }

    /// Sample rate of the measured tracks; 0 until tracks are loaded.
    var sampleRate: Double {
        readerLock.withLock { rate }
    }

    /// Goes up on every `reset`, so a reader can tell a new song was loaded.
    var generation: Int {
        readerLock.withLock { resetCount }
    }

    /// Groups whose tracks never count toward the mix (click, cues, timecode).
    var excludedGroupIDs: Set<UUID> {
        get { readerLock.withLock { excludedGroups } }
        set { readerLock.withLock { excludedGroups = newValue } }
    }

    /// Clears the ring and gives each track a slot, in order, up to `maxSlots`. Returns the
    /// slot for each track that got one. Call only while the engine is stopped.
    @discardableResult
    func reset(sampleRate: Double, trackIDs: [UUID]) -> [UUID: Int] {
        readerLock.withLock {
            left.update(repeating: 0, count: Self.capacity)
            right.update(repeating: 0, count: Self.capacity)
            cursors.update(repeating: 0, count: Self.maxSlots)
            slotStates.update(repeating: 0, count: Self.maxSlots)
            slotByTrackID = [:]
            for (slot, id) in trackIDs.prefix(Self.maxSlots).enumerated() {
                slotByTrackID[id] = slot
                slotStates[slot] = 1
            }
            slotCount = slotByTrackID.count
            readPosition = 0
            rate = sampleRate
            resetCount += 1
            return slotByTrackID
        }
    }

    /// Whether the track's audio counts toward the mix. Its slot keeps advancing either way.
    func setMeasured(_ measured: Bool, trackID: UUID) {
        readerLock.withLock {
            guard let slot = slotByTrackID[trackID] else { return }
            slotStates[slot] = measured ? 2 : 1
        }
    }

    /// Render thread: adds one track's rendered block. Mono stems feed both sides.
    func add(slot: Int, buffers: UnsafeMutableAudioBufferListPointer, frameCount: Int) {
        guard slot >= 0, slot < Self.maxSlots, slotStates[slot] != 0 else { return }
        // A track that stopped rendering for a while rejoins where the meter is reading, so its
        // audio never lands on frames that belong to later blocks.
        let start = max(cursors[slot], readPosition)
        if slotStates[slot] == 2, buffers.count > 0,
           let leftSource = buffers[0].mData?.assumingMemoryBound(to: Float.self) {
            let rightSource = buffers.count > 1
                ? buffers[1].mData?.assumingMemoryBound(to: Float.self) ?? leftSource
                : leftSource
            for frame in 0..<frameCount {
                let index = Int((start + Int64(frame)) & Self.mask)
                left[index] += leftSource[frame]
                right[index] += rightSource[frame]
            }
        }
        cursors[slot] = start + Int64(frameCount)
    }

    /// Hands every complete frame since the last read to `consume`, in at most two contiguous
    /// runs, then clears them. Skips ahead if the reader fell so far behind that the ring wrapped.
    func read(_ consume: (UnsafePointer<Float>, UnsafePointer<Float>, Int) -> Void) {
        readerLock.withLock {
            guard slotCount > 0 else { return }
            // Wait only for measured tracks: a left-out one (click, timecode) adds nothing. A
            // measured track that has stopped rendering altogether (far behind the others) is
            // skipped too, so one silent node can never freeze the meter.
            var newest = Int64.min
            for slot in 0..<slotCount where slotStates[slot] == 2 {
                newest = max(newest, cursors[slot])
            }
            guard newest > Int64.min else { return }
            let stalled = newest - Int64(Self.capacity / 4)
            var ready = newest
            for slot in 0..<slotCount where slotStates[slot] == 2 && cursors[slot] >= stalled {
                ready = min(ready, cursors[slot])
            }
            guard ready > readPosition else { return }
            if ready - readPosition > Int64(Self.capacity / 2) {
                // Too far behind: what is left in the ring may already be overwritten.
                left.update(repeating: 0, count: Self.capacity)
                right.update(repeating: 0, count: Self.capacity)
                readPosition = ready
                return
            }
            while readPosition < ready {
                let index = Int(readPosition & Self.mask)
                let run = min(Int(ready - readPosition), Self.capacity - index)
                consume(left + index, right + index, run)
                (left + index).update(repeating: 0, count: run)
                (right + index).update(repeating: 0, count: run)
                readPosition += Int64(run)
            }
        }
    }
}
