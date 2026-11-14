import XCTest
@testable import CuesLive

final class ClipSnappingTests: XCTestCase {
    private let drums = UUID()
    private let bass = UUID()

    func testTargetsSkipExcludedClipsAndIncludeExtras() {
        let moving = TrackClip(trackID: drums, timelineStartSeconds: 0, duration: 10, sourceStartSeconds: 0)
        let neighbor = TrackClip(trackID: bass, timelineStartSeconds: 12, duration: 8, sourceStartSeconds: 0)
        let targets = ClipSnapping.targets(
            clips: [moving, neighbor],
            excluding: [moving.id],
            extraTargets: [5, 12]
        )
        XCTAssertEqual(targets, [5, 12, 20])
    }

    func testMoveSnapsLeadingEdgeToNearbyTarget() {
        let snap = ClipSnapping.snap(edges: [10, 20], rawDelta: 1.9, targets: [12], threshold: 0.25)
        XCTAssertEqual(snap, ClipSnapping.Snap(delta: 2, target: 12))
    }

    func testMoveSnapsTrailingEdgeWhenItIsCloser() {
        let snap = ClipSnapping.snap(edges: [10, 20], rawDelta: 4.95, targets: [15.2, 25], threshold: 0.25)
        XCTAssertEqual(snap, ClipSnapping.Snap(delta: 5, target: 25))
    }

    func testNoSnapOutsideThreshold() {
        XCTAssertNil(ClipSnapping.snap(edges: [10], rawDelta: 1, targets: [12], threshold: 0.5))
    }

    func testSingleEdgeTrimSnap() {
        let snap = ClipSnapping.snap(edges: [33.9], rawDelta: 0, targets: [30, 34], threshold: 0.2)
        XCTAssertEqual(snap?.target, 34)
        XCTAssertEqual(snap?.delta ?? 0, 0.1, accuracy: 1e-9)
    }
}
