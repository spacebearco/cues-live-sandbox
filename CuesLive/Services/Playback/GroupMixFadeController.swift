import Foundation
import Observation
import SwiftData

/// Ramps all group faders except Click and Timecode (plus No Group) between their levels and
/// silence, over a length the caller works out from the song (`FadeButtonSettings`). A low-pass
/// sweep follows the fade unless it is turned off: `filterClosure` goes from 0 (open) to 1
/// (closed) as the level falls.
///
/// While a fade runs, the in-between levels live here and reach the engine through
/// `applying(to:)`; the groups' saved volumes are written once, when the fade lands. Writing
/// them on every step redrew everything that shows a group (meters included) sixty times a
/// second, which made the screen stutter.
@MainActor
@Observable
final class GroupMixFadeController {
    private static let stepInterval: TimeInterval = 1.0 / 60.0
    private static let ungroupedID = OutputRoutingStore.ungroupedRouteID

    private(set) var isFadedOut = false
    private(set) var isFading = false
    /// True while the standalone filter sweep is closed or closing (`toggleFilterSweep`).
    private(set) var isFilterSwept = false

    @ObservationIgnored private(set) var filterClosure = 0.0
    /// Levels the running fade has reached, by group (and `ungroupedID`). Empty when idle.
    @ObservationIgnored private var liveVolumes: [UUID: Double] = [:]
    /// The groups the fade and its filter sweep act on.
    @ObservationIgnored private var fadedGroupIDs: Set<UUID> = []
    @ObservationIgnored private var phase: Phase = .idle
    @ObservationIgnored private var savedVolumes: [UUID: Double] = [:]
    @ObservationIgnored private var rampGeneration = 0

    private enum Phase {
        case idle
        case fadingOut
        case fadedOut
        case fadingIn
    }

    private func setPhase(_ newPhase: Phase) {
        phase = newPhase
        isFadedOut = newPhase == .fadingOut || newPhase == .fadedOut
        isFading = newPhase == .fadingOut || newPhase == .fadingIn
    }

    /// `snapshot` as the fade has it now: the faded groups at their in-between levels, with the
    /// filter sweep on them. Unchanged when no fade is running.
    func applying(to snapshot: GroupMixSnapshot) -> GroupMixSnapshot {
        guard !liveVolumes.isEmpty || filterClosure > 0 else { return snapshot }
        var volumes = snapshot.volumeByGroupID
        for (groupID, volume) in liveVolumes where groupID != Self.ungroupedID {
            volumes[groupID] = Float(volume)
        }
        var result = GroupMixSnapshot(
            volumeByGroupID: volumes,
            mutedGroupIDs: snapshot.mutedGroupIDs,
            ungroupedVolume: liveVolumes[Self.ungroupedID].map(Float.init) ?? snapshot.ungroupedVolume,
            ungroupedIsMuted: snapshot.ungroupedIsMuted,
            fadeFilter: snapshot.fadeFilter
        )
        if filterClosure > 0 {
            result.fadeFilter = GroupMixSnapshot.FadeFilter(
                closure: filterClosure,
                groupIDs: fadedGroupIDs,
                includesUngrouped: true
            )
        }
        return result
    }

    /// Stops the ramp where it is. The levels it reached stay in effect.
    func cancel() {
        rampGeneration += 1
        switch phase {
        case .fadingOut, .fadingIn:
            setPhase(.fadedOut)
        case .idle, .fadedOut:
            break
        }
    }

    func reset() {
        rampGeneration += 1
        savedVolumes = [:]
        liveVolumes = [:]
        filterClosure = 0
        isFilterSwept = false
        setPhase(.idle)
    }

    /// Stops any in-flight fade and immediately restores saved group levels.
    func clearFade(context: ModelContext, onMixChange: @escaping () -> Void) {
        rampGeneration += 1
        liveVolumes = [:]
        filterClosure = 0
        isFilterSwept = false

        guard !savedVolumes.isEmpty else {
            setPhase(.idle)
            onMixChange()
            return
        }

        for group in fadeableGroups(in: context) {
            if let volume = savedVolumes[group.id] {
                group.volume = volume
            }
        }
        if let volume = savedVolumes[Self.ungroupedID] {
            OutputRoutingStore.config(in: context).ungroupedVolume = volume
        }

        savedVolumes = [:]
        setPhase(.idle)
        onMixChange()
    }

    /// Fades out, or back in when faded out, over `duration` seconds.
    func toggleFade(
        context: ModelContext,
        duration: TimeInterval,
        onMixChange: @escaping () -> Void,
        onComplete: (() -> Void)? = nil
    ) {
        switch phase {
        case .idle, .fadingIn:
            beginFadeOut(context: context, duration: duration, onMixChange: onMixChange, onComplete: onComplete)
        case .fadingOut, .fadedOut:
            beginFadeIn(context: context, duration: duration, onMixChange: onMixChange, onComplete: onComplete)
        }
    }

    /// Closes the low-pass filter over `duration` seconds without touching the levels, or opens
    /// it again. Does nothing while a fade is running or faded out; the fade owns the filter then.
    func toggleFilterSweep(
        context: ModelContext,
        duration: TimeInterval,
        onMixChange: @escaping () -> Void
    ) {
        guard phase == .idle else { return }
        isFilterSwept.toggle()
        startRamp(
            targets: [:],
            filterTarget: isFilterSwept ? 1 : 0,
            sweepsFilter: true,
            duration: duration,
            context: context,
            onMixChange: onMixChange,
            onComplete: {}
        )
    }

    private func beginFadeOut(
        context: ModelContext,
        duration: TimeInterval,
        onMixChange: @escaping () -> Void,
        onComplete: (() -> Void)?
    ) {
        let groups = fadeableGroups(in: context)
        if savedVolumes.isEmpty {
            var saved: [UUID: Double] = [:]
            for group in groups {
                saved[group.id] = group.volume
            }
            saved[Self.ungroupedID] = OutputRoutingStore.config(in: context).ungroupedVolume
            savedVolumes = saved
        }

        var targets: [UUID: Double] = [Self.ungroupedID: 0]
        for group in groups {
            targets[group.id] = 0
        }

        setPhase(.fadingOut)
        startRamp(
            targets: targets,
            filterTarget: 1,
            duration: duration,
            context: context,
            onMixChange: onMixChange
        ) { [weak self] in
            self?.setPhase(.fadedOut)
            onComplete?()
        }
    }

    private func beginFadeIn(
        context: ModelContext,
        duration: TimeInterval,
        onMixChange: @escaping () -> Void,
        onComplete: (() -> Void)?
    ) {
        guard !savedVolumes.isEmpty else {
            setPhase(.idle)
            return
        }

        let groups = fadeableGroups(in: context)
        var targets: [UUID: Double] = [:]
        for group in groups {
            targets[group.id] = savedVolumes[group.id] ?? group.volume
        }
        targets[Self.ungroupedID] = savedVolumes[Self.ungroupedID]
            ?? OutputRoutingStore.config(in: context).ungroupedVolume

        setPhase(.fadingIn)
        startRamp(
            targets: targets,
            filterTarget: 0,
            duration: duration,
            context: context,
            onMixChange: onMixChange
        ) { [weak self] in
            self?.savedVolumes = [:]
            self?.isFilterSwept = false
            self?.setPhase(.idle)
            onComplete?()
        }
    }

    /// Ramps from where the levels are now (mid-fade or saved) to `targets`, then writes the
    /// targets to the groups once.
    private func startRamp(
        targets: [UUID: Double],
        filterTarget: Double,
        sweepsFilter: Bool = FadeButtonSettings.sweepsFilter,
        duration: TimeInterval,
        context: ModelContext,
        onMixChange: @escaping () -> Void,
        onComplete: @escaping () -> Void
    ) {
        rampGeneration += 1
        let generation = rampGeneration
        let groups = fadeableGroups(in: context)
        let config = OutputRoutingStore.config(in: context)
        fadedGroupIDs = Set(groups.map(\.id))

        var starts: [UUID: Double] = [:]
        for group in groups where targets[group.id] != nil {
            starts[group.id] = liveVolumes[group.id] ?? group.volume
        }
        if targets[Self.ungroupedID] != nil {
            starts[Self.ungroupedID] = liveVolumes[Self.ungroupedID] ?? config.ungroupedVolume
        }

        let filterStart = filterClosure
        let sweeps = sweepsFilter
        let length = max(duration, Self.stepInterval)
        let began = ProcessInfo.processInfo.systemUptime

        Task { @MainActor [weak self] in
            while true {
                guard let self, self.rampGeneration == generation else { return }
                let t = min(1, (ProcessInfo.processInfo.systemUptime - began) / length)
                for (groupID, target) in targets {
                    let start = starts[groupID] ?? target
                    self.liveVolumes[groupID] = start + (target - start) * t
                }
                self.filterClosure = sweeps
                    ? filterStart + (filterTarget - filterStart) * Self.sweepCurve(t)
                    : 0
                onMixChange()
                if t >= 1 { break }
                try? await Task.sleep(for: .seconds(Self.stepInterval))
            }
            guard let self, self.rampGeneration == generation else { return }
            for group in groups {
                if let target = targets[group.id] {
                    group.volume = target
                }
            }
            if let target = targets[Self.ungroupedID] {
                config.ungroupedVolume = target
            }
            self.liveVolumes = [:]
            onComplete()
        }
    }

    /// The filter moves ahead of the level (half way by a quarter of the fade), so the sweep is
    /// heard while the song is still loud rather than once it has faded.
    nonisolated static func sweepCurve(_ t: Double) -> Double {
        let clamped = min(max(t, 0), 1)
        return 1 - (1 - clamped) * (1 - clamped) * (1 - clamped)
    }

    private func fadeableGroups(in context: ModelContext) -> [TrackGroup] {
        TrackGroupStore.sortedGroups(from: context).filter { !Self.isExcludedFromFade($0) }
    }

    private static func isExcludedFromFade(_ group: TrackGroup) -> Bool {
        TrackGroupStore.isGroup(group, named: TrackGroupStore.clickGroupName)
            || TimecodePlaybackSupport.isTimecodeGroup(group)
    }
}
