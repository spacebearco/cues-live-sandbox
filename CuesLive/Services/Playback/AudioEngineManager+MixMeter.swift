import Foundation

/// Feeds the setlist mix meter: which tracks add into `mixMeterBus`, and which count.
extension AudioEngineManager {
    /// Groups the meter leaves out (click, cues, timecode). Tracks in them still play.
    func setMixMeterExcludedGroups(_ groupIDs: Set<UUID>) {
        guard mixMeterBus.excludedGroupIDs != groupIDs else { return }
        mixMeterBus.excludedGroupIDs = groupIDs
        refreshMixMeterMeasuredTracks()
    }

    /// Gives every loaded track at the most common sample rate a meter slot. Tracks at another
    /// rate would drift against the rest, so they are left out. Call while the engine is stopped.
    func configureMixMeter() {
        let ordered = tracks.values.sorted { $0.trackID.uuidString < $1.trackID.uuidString }
        let rateCounts = Dictionary(grouping: ordered, by: { $0.sourceFormat.sampleRate }).mapValues(\.count)
        let rate = rateCounts.max { $0.value < $1.value }?.key ?? 0
        let metered = ordered.filter { $0.sourceFormat.sampleRate == rate }
        let slots = mixMeterBus.reset(sampleRate: rate, trackIDs: metered.map(\.trackID))
        for track in ordered {
            if let slot = slots[track.trackID] {
                track.memoryPlayer.attachMixMeter(mixMeterBus, slot: slot)
            } else {
                track.memoryPlayer.attachMixMeter(nil, slot: -1)
            }
        }
        refreshMixMeterMeasuredTracks()
    }

    /// A track counts unless its group is excluded or show routing sends it nowhere.
    func refreshMixMeterMeasuredTracks() {
        let excluded = mixMeterBus.excludedGroupIDs
        for track in tracks.values {
            var measured = !(track.groupID.map(excluded.contains) ?? false)
            if measured, let routing = routingSnapshot,
               case .none = OutputRoutingStore.destination(for: track.groupID, snapshot: routing) {
                measured = false
            }
            mixMeterBus.setMeasured(measured, trackID: track.trackID)
        }
    }
}

extension AudioEngineManager {
    /// Group names the setlist meter leaves out: they carry click, spoken cues and timecode.
    static let mixMeterExcludedGroupNames: Set<String> = ["click", "cues", "timecode"]

    /// IDs of the groups the setlist meter leaves out, matched by name, ignoring case and spaces.
    static func mixMeterExcludedGroupIDs(in groups: [TrackGroup]) -> Set<UUID> {
        Set(groups.compactMap { group in
            let name = group.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return mixMeterExcludedGroupNames.contains(name) ? group.id : nil
        })
    }
}
