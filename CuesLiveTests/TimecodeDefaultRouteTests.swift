import SwiftData
import XCTest
@testable import CuesLive

final class TimecodeDefaultRouteTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(PersistenceController.modelTypes),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)
        TrackGroupStore.ensureDefaults(in: context)
        OutputRoutingStore.ensureConfig(in: context)
        return context
    }

    func testTimecodeGroupDefaultsToNoOutputAndOthersToMain() throws {
        let context = try makeContext()
        let groups = try context.fetch(FetchDescriptor<TrackGroup>())
        let timecode = try XCTUnwrap(groups.first(where: TimecodePlaybackSupport.isTimecodeGroup))
        let drums = try XCTUnwrap(groups.first { !TimecodePlaybackSupport.isTimecodeGroup($0) })

        XCTAssertEqual(OutputRoutingStore.route(for: timecode.id, deviceUID: nil, in: context), OutputDestination.none)
        XCTAssertEqual(OutputRoutingStore.route(for: drums.id, deviceUID: nil, in: context), .defaultDestination)

        let snapshot = OutputRoutingStore.snapshot(in: context, channelCount: 2)
        XCTAssertEqual(OutputRoutingStore.destination(for: timecode.id, snapshot: snapshot), OutputDestination.none)
        XCTAssertEqual(OutputRoutingStore.destination(for: drums.id, snapshot: snapshot), .defaultDestination)
    }

    func testChosenTimecodeRouteStillWins() throws {
        let context = try makeContext()
        let timecode = try XCTUnwrap(
            try context.fetch(FetchDescriptor<TrackGroup>()).first(where: TimecodePlaybackSupport.isTimecodeGroup)
        )
        OutputRoutingStore.setRoute(.mono(channel: 2), for: timecode.id, deviceUID: nil, in: context)
        let snapshot = OutputRoutingStore.snapshot(in: context, channelCount: 4)
        XCTAssertEqual(OutputRoutingStore.destination(for: timecode.id, snapshot: snapshot), .mono(channel: 2))
    }
}
