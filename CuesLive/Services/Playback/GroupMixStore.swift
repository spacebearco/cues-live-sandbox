import Foundation
import SwiftData

struct GroupMixSnapshot: Sendable {
    /// The Fade button's low-pass sweep: how far it is closed, and on which groups.
    struct FadeFilter: Sendable, Equatable {
        /// 0 open (no filtering) … 1 closed down to `LowPassSweep.minimumHz`.
        var closure: Double = 0
        var groupIDs: Set<UUID> = []
        var includesUngrouped = false

        func closure(forGroup groupID: UUID?) -> Double {
            let applies = groupID.map(groupIDs.contains) ?? includesUngrouped
            return applies ? closure : 0
        }
    }

    let volumeByGroupID: [UUID: Float]
    let mutedGroupIDs: Set<UUID>
    let ungroupedVolume: Float
    let ungroupedIsMuted: Bool
    var fadeFilter = FadeFilter()

    static let `default` = GroupMixSnapshot(
        volumeByGroupID: [:],
        mutedGroupIDs: [],
        ungroupedVolume: 1,
        ungroupedIsMuted: false
    )

    func replacingVolume(groupID: UUID?, volume: Float) -> GroupMixSnapshot {
        if let groupID {
            var volumes = volumeByGroupID
            volumes[groupID] = volume
            return GroupMixSnapshot(
                volumeByGroupID: volumes,
                mutedGroupIDs: mutedGroupIDs,
                ungroupedVolume: ungroupedVolume,
                ungroupedIsMuted: ungroupedIsMuted,
                fadeFilter: fadeFilter
            )
        }

        return GroupMixSnapshot(
            volumeByGroupID: volumeByGroupID,
            mutedGroupIDs: mutedGroupIDs,
            ungroupedVolume: volume,
            ungroupedIsMuted: ungroupedIsMuted,
            fadeFilter: fadeFilter
        )
    }
}

enum GroupMixStore {
    static func snapshot(in context: ModelContext) -> GroupMixSnapshot {
        let groups = TrackGroupStore.sortedGroups(from: context)
        var volumeByGroupID: [UUID: Float] = [:]
        var mutedGroupIDs = Set<UUID>()

        for group in groups {
            if TimecodePlaybackSupport.isTimecodeGroup(group) {
                // LTC must stay at unity; it has no mixer fader.
                volumeByGroupID[group.id] = 1
            } else {
                volumeByGroupID[group.id] = Float(group.volume)
                if group.isMuted {
                    mutedGroupIDs.insert(group.id)
                }
            }
        }

        let config = OutputRoutingStore.config(in: context)
        return GroupMixSnapshot(
            volumeByGroupID: volumeByGroupID,
            mutedGroupIDs: mutedGroupIDs,
            ungroupedVolume: Float(config.ungroupedVolume),
            ungroupedIsMuted: config.ungroupedIsMuted
        )
    }
}
