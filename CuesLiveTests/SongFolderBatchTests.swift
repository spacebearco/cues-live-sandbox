import XCTest
@testable import CuesLive

final class SongFolderBatchTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SongFolderBatchTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeFolder(_ path: String, files: [String] = []) throws -> URL {
        let url = root.appendingPathComponent(path, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for file in files {
            FileManager.default.createFile(atPath: url.appendingPathComponent(file).path, contents: Data())
        }
        return url
    }

    func testSongFolderStaysAsOneSong() throws {
        let song = try makeFolder("Song A", files: ["drums.wav", "bass.wav"])
        XCTAssertEqual(SongFolderImporter.songFolders(from: [song]).map(\.lastPathComponent), ["Song A"])
    }

    func testFolderOfSongFoldersExpandsInNameOrder() throws {
        let library = try makeFolder("Library")
        _ = try makeFolder("Library/Song 10", files: ["a.wav"])
        _ = try makeFolder("Library/Song 2", files: ["a.aif"])
        _ = try makeFolder("Library/Song 1", files: ["set.als"])
        XCTAssertEqual(
            SongFolderImporter.songFolders(from: [library]).map(\.lastPathComponent),
            ["Song 1", "Song 2", "Song 10"]
        )
    }

    func testSongFolderWithSubfoldersIsNotExpanded() throws {
        let song = try makeFolder("Song B", files: ["vox.wav"])
        _ = try makeFolder("Song B/Ableton Project Info")
        XCTAssertEqual(SongFolderImporter.songFolders(from: [song]).map(\.lastPathComponent), ["Song B"])
    }
}
