import XCTest
@testable import CuesLive

final class ClipMuteAndClipboardTests: XCTestCase {
    private let drums = UUID()
    private let bass = UUID()

    private func clip(_ track: UUID, _ start: TimeInterval, _ duration: TimeInterval, source: TimeInterval? = nil) -> TrackClip {
        TrackClip(trackID: track, timelineStartSeconds: start, duration: duration, sourceStartSeconds: source ?? start)
    }

    func testToggleMuteMutesThenUnmutes() {
        var clips = [clip(drums, 0, 10), clip(bass, 0, 10)]
        let ids = Set(clips.map(\.id))
        XCTAssertTrue(ClipEditing.toggleMute(clipIDs: ids, in: &clips))
        XCTAssertTrue(clips.allSatisfy(\.isMuted))
        XCTAssertFalse(ClipEditing.toggleMute(clipIDs: ids, in: &clips))
        XCTAssertFalse(clips.contains(where: \.isMuted))
    }

    func testMutingARangeSplitsAndMutesOnlyTheRange() {
        var clips = [clip(drums, 0, 10), clip(bass, 0, 10)]
        let inside = ClipEditing.toggleMute(trackIDs: [drums], from: 4, to: 6, in: &clips)
        let drumClips = clips.filter { $0.trackID == drums }.sorted { $0.timelineStartSeconds < $1.timelineStartSeconds }
        XCTAssertEqual(drumClips.map(\.timelineStartSeconds), [0, 4, 6])
        XCTAssertEqual(drumClips.map(\.isMuted), [false, true, false])
        XCTAssertEqual(inside, [drumClips[1].id])
        XCTAssertFalse(clips.first { $0.trackID == bass }?.isMuted ?? true)
    }

    func testMutedClipPlaysSilenceAndSurvivesSaving() throws {
        var muted = clip(drums, 0, 10)
        muted.isMuted = true
        let mapper = ArrangementTimelineMapper(clips: [muted, clip(drums, 10, 5)], fileDuration: 20)
        XCTAssertNil(mapper.sourceSeconds(atMasterTimeline: 5))
        XCTAssertEqual(mapper.sourceSeconds(atMasterTimeline: 12), 12)

        let decoded = try JSONDecoder().decode(TrackClip.self, from: JSONEncoder().encode(muted))
        XCTAssertTrue(decoded.isMuted)
        let legacy = try JSONDecoder().decode(TrackClip.self, from: JSONEncoder().encode(clip(drums, 0, 1)))
        XCTAssertFalse(legacy.isMuted)
    }

    func testCopyClipsAndPasteLaterOnTheSameTracks() throws {
        var clips = [clip(drums, 2, 4), clip(bass, 3, 4)]
        let board = try XCTUnwrap(ClipClipboard.copying(clipIDs: Set(clips.map(\.id)), from: clips))
        XCTAssertEqual(board.span, 5)
        let pasted = board.paste(at: 20, into: &clips)
        XCTAssertEqual(pasted.count, 2)
        let copies = clips.filter { pasted.contains($0.id) }.sorted { $0.timelineStartSeconds < $1.timelineStartSeconds }
        XCTAssertEqual(copies.map(\.timelineStartSeconds), [20, 21])
        XCTAssertEqual(copies.map(\.trackID), [drums, bass])
        XCTAssertEqual(copies.map(\.sourceStartSeconds), [2, 3])
    }

    func testCopyRangeTakesPartsOfClipsAndPasteReplacesWhatIsThere() throws {
        var clips = [clip(drums, 0, 10)]
        let board = try XCTUnwrap(ClipClipboard.copying(trackIDs: [drums], from: 2, to: 4, in: clips))
        XCTAssertEqual(board.clips.first?.sourceStartSeconds, 2)
        XCTAssertEqual(board.clips.first?.duration ?? 0, 2, accuracy: 1e-9)
        _ = board.paste(at: 6, into: &clips)
        let sorted = clips.sorted { $0.timelineStartSeconds < $1.timelineStartSeconds }
        XCTAssertEqual(sorted.map(\.timelineStartSeconds), [0, 6, 8])
        XCTAssertEqual(sorted[1].sourceStartSeconds, 2)
    }

    func testSplitDoesNotChangeWhatPlays() {
        var clips = [clip(drums, 0, 10)]
        let before = ArrangementTimelineMapper(clips: clips, fileDuration: 20)
        _ = ClipEditing.split(clipIDs: Set(clips.map(\.id)), at: 5, in: &clips)
        let after = ArrangementTimelineMapper(clips: clips, fileDuration: 20)
        XCTAssertNotEqual(before, after)
        XCTAssertNil(before.firstDifference(from: after, at: 4.95, within: 0.1))
    }

    func testMovingTheClipUnderThePlayheadIsAChangeNow() {
        let original = clip(drums, 0, 10)
        var moved = original
        moved.timelineStartSeconds = 1
        let before = ArrangementTimelineMapper(clips: [original], fileDuration: 20)
        let after = ArrangementTimelineMapper(clips: [moved], fileDuration: 20)
        XCTAssertEqual(before.firstDifference(from: after, at: 5, within: 0.1), 5)
    }

    func testUpcomingJumpPointsAtTheNextClipsSource() {
        let mapper = ArrangementTimelineMapper(
            clips: [clip(drums, 0, 10), clip(drums, 10, 5, source: 40), clip(drums, 15, 5, source: 45)],
            fileDuration: 60
        )
        XCTAssertNil(mapper.upcomingJumpSource(afterMasterTimeline: 5, within: 2))
        XCTAssertEqual(mapper.upcomingJumpSource(afterMasterTimeline: 9, within: 2), 40)
        // 10..15 carries straight on into 15..20 in the file: no jump.
        XCTAssertNil(mapper.upcomingJumpSource(afterMasterTimeline: 14, within: 2))
    }
}
