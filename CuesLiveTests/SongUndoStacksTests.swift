import XCTest
@testable import CuesLive

@MainActor
final class SongUndoStacksTests: XCTestCase {
    private func makeSong() -> (Song, AudioTrack, AudioTrack) {
        let song = Song(name: "Fader Undo \(UUID())")
        let keys = AudioTrack(displayName: "Keys", relativeFilePath: "keys.wav", sortOrder: 0)
        let pads = AudioTrack(displayName: "Pads", relativeFilePath: "pads.wav", sortOrder: 1)
        keys.song = song
        pads.song = song
        song.tracks = [keys, pads]
        return (song, keys, pads)
    }

    func testSameSongSharesOneStack() {
        let songID = UUID()
        XCTAssertTrue(SongUndoStacks.controller(for: songID) === SongUndoStacks.controller(for: songID))
        XCTAssertFalse(SongUndoStacks.controller(for: songID) === SongUndoStacks.controller(for: UUID()))
    }

    func testTrackGainChangeUndoesAndRedoes() {
        let (song, keys, pads) = makeSong()
        keys.volume = 0.5
        pads.volume = 0.25
        let before = [keys.id: 0.5, pads.id: 0.25]
        keys.volume = 1.0
        pads.volume = 0.5
        var appliedCount = 0

        SongUndoStacks.registerTrackGainChange(
            "Change Group Level",
            song: song,
            before: before,
            after: [keys.id: 1.0, pads.id: 0.5],
            apply: { _ in appliedCount += 1 }
        )
        let controller = SongUndoStacks.controller(for: song.id)
        XCTAssertEqual(controller.undoActionName, "Change Group Level")

        controller.undo()
        XCTAssertEqual(keys.volume, 0.5)
        XCTAssertEqual(pads.volume, 0.25)
        XCTAssertEqual(appliedCount, 1)

        controller.redo()
        XCTAssertEqual(keys.volume, 1.0)
        XCTAssertEqual(pads.volume, 0.5)
        XCTAssertEqual(appliedCount, 2)
    }

    func testUnchangedGainsAddNoStep() {
        let (song, keys, _) = makeSong()
        SongUndoStacks.registerTrackGainChange(
            "Change Group Level",
            song: song,
            before: [keys.id: 0.8],
            after: [keys.id: 0.8],
            apply: { _ in }
        )
        XCTAssertFalse(SongUndoStacks.controller(for: song.id).canUndo)
    }

    func testClearDropsEveryStep() {
        let (song, keys, _) = makeSong()
        SongUndoStacks.registerTrackGainChange(
            "Change Group Level",
            song: song,
            before: [keys.id: 0.2],
            after: [keys.id: 0.9],
            apply: { _ in }
        )
        SongUndoStacks.clear(for: song.id)
        XCTAssertFalse(SongUndoStacks.controller(for: song.id).canUndo)
    }
}
