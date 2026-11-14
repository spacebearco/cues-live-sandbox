import AVFoundation
import SwiftData
import XCTest
@testable import CuesLive

final class SplitToMonoTests: XCTestCase {
    /// A stereo file whose left channel is all 0.25 and right all -0.5.
    private func writeStereoFile() throws -> URL {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_800))
        pcm.frameLength = 4_800
        let data = try XCTUnwrap(pcm.floatChannelData)
        for frame in 0..<4_800 {
            data[0][frame] = 0.25
            data[1][frame] = -0.5
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("split-\(UUID()).caf")
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: pcm)
        return url
    }

    func testChannelSelectedSourcePlaysOneChannelOnBothSides() throws {
        let url = try writeStereoFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let stream = try StreamingStemBuffer(url: url)
        stream.prewarm(aroundSourceFrame: 0)
        let right = ChannelSelectedSource(base: stream, channel: 1)
        var out = [Float](repeating: 0, count: 8)
        out.withUnsafeMutableBufferPointer { pointer in
            guard let base = pointer.baseAddress else { return }
            right.copy(channel: 0, startingFrame: 100, frameCount: 4, into: base, destinationOffset: 0, gain: 1)
            right.copy(channel: 1, startingFrame: 100, frameCount: 4, into: base, destinationOffset: 4, gain: 1)
        }
        XCTAssertEqual(out, [Float](repeating: -0.5, count: 8))
        XCTAssertEqual(right.channelCount, 2)
    }

    func testSplitMakesLeftAndRightTracksWithCopiedClips() throws {
        let url = try writeStereoFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let container = try ModelContainer(
            for: Schema(PersistenceController.modelTypes),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)
        let song = Song(name: "Split")
        context.insert(song)
        let keys = AudioTrack(displayName: "Keys", relativeFilePath: "keys.caf", sortOrder: 0)
        let bass = AudioTrack(displayName: "Bass", relativeFilePath: "bass.caf", sortOrder: 1)
        for track in [keys, bass] {
            track.song = song
            context.insert(track)
            song.tracks.append(track)
        }
        keys.volume = 0.5
        var timeline = SongTimeline(clips: [
            TrackClip(trackID: keys.id, timelineStartSeconds: 0, duration: 10, sourceStartSeconds: 0, gainDB: -3),
            TrackClip(trackID: bass.id, timelineStartSeconds: 0, duration: 10, sourceStartSeconds: 0),
        ])

        XCTAssertTrue(TrackChannelSplitter.canSplit(keys, fileURL: url))
        let right = TrackChannelSplitter.split(keys, in: song, timeline: &timeline, context: context)

        XCTAssertEqual(keys.displayName, "Keys L")
        XCTAssertEqual(right.displayName, "Keys R")
        XCTAssertEqual(keys.sourceChannel, 0)
        XCTAssertEqual(right.sourceChannel, 1)
        XCTAssertEqual(keys.pan, -1)
        XCTAssertEqual(right.pan, 1)
        XCTAssertEqual(right.volume, 0.5)
        XCTAssertEqual(song.sortedTracks.map(\.displayName), ["Keys L", "Keys R", "Bass"])
        let rightClips = timeline.clips.filter { $0.trackID == right.id }
        XCTAssertEqual(rightClips.count, 1)
        XCTAssertEqual(rightClips.first?.gainDB, -3)
        XCTAssertFalse(TrackChannelSplitter.canSplit(keys, fileURL: url))
    }

    func testSourceChannelSavesInTheProjectMix() throws {
        let track = AudioTrack(displayName: "Keys", relativeFilePath: "k.caf", sortOrder: 0)
        track.sourceChannel = 1
        let mix = ProjectTrackMix(from: track)
        let decoded = try JSONDecoder().decode(ProjectTrackMix.self, from: JSONEncoder().encode(mix))
        XCTAssertEqual(decoded.sourceChannel, 1)
    }

    func testRMSFollowsTheSignalAndFallsAwayWhenItStops() {
        let holder = PeakMeterHolder()
        for _ in 0..<60 { holder.reportMeanSquare(0.25) }
        XCTAssertEqual(holder.rms(), 0.5, accuracy: 0.01)
        holder.reset()
        XCTAssertEqual(holder.rms(), 0)
    }
}
