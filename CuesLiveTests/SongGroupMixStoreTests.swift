import XCTest
@testable import CuesLive

final class SongGroupMixStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "SongGroupMixStoreTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testSongWithoutAMixHasNoLevels() {
        XCTAssertNil(SongGroupMixStore(defaults: defaults).levels(for: UUID()))
    }

    func testEachSongKeepsItsOwnLevels() {
        let store = SongGroupMixStore(defaults: defaults)
        let drums = UUID()
        let songA = UUID()
        let songB = UUID()

        store.save([drums: 0.5], for: songA)
        store.save([drums: 1.25], for: songB)

        XCTAssertEqual(store.levels(for: songA), [drums: 0.5])
        XCTAssertEqual(store.levels(for: songB), [drums: 1.25])
    }

    func testSavingAgainReplacesTheSongsLevels() {
        let store = SongGroupMixStore(defaults: defaults)
        let drums = UUID()
        let song = UUID()

        store.save([drums: 0.5], for: song)
        store.save([drums: 0.8], for: song)

        XCTAssertEqual(store.levels(for: song), [drums: 0.8])
    }
}
