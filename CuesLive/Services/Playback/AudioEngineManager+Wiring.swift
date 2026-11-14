import AVFoundation
import Foundation

/// Connecting track outputs to the device: show routing with channel maps, or the master mix.
extension AudioEngineManager {
    func wireTrackOutputs(routing: OutputRoutingSnapshot) throws {
        stopEngineForGraphChanges()
        let boundRequestedDevice = adoptOutputDevice(routing.deviceUID)
        // A stale/missing device UID must not force multi-channel maps onto whatever
        // output the engine actually opened — that leaves the graph silent.
        let channelCount = (routing.deviceUID != nil && !boundRequestedDevice)
            ? 2
            : outputChannelCount(for: routing)
        disconnectTrackOutputs()
        connectTrackOutputs(routing: routing, channelCount: channelCount)
        try startEngineIfNeeded()
    }

    func adoptOutputDevice(_ deviceUID: String?) -> Bool {
        guard let deviceUID else { return true }
        // Bind only this engine's output unit — do not change the system default.
        let bound = AudioOutputDeviceService.bindOutputDevice(uid: deviceUID, to: engine)
        applyStableMaximumFramesToRender()
        return bound
    }

    private func disconnectTrackOutputs() {
        for track in tracks.values {
            engine.disconnectNodeOutput(track.memoryPlayer.sourceNode)
            engine.disconnectNodeOutput(track.timePitchNode)
        }
    }

    private func connectTrackOutputs(routing: OutputRoutingSnapshot, channelCount: Int) {
        restoreFullOutputGain()

        // Channel-map routing is also needed on a stereo-only (2-channel) device
        // whenever a group is pinned to a single mono channel instead of the
        // default full stereo pair — otherwise every group would always spread
        // across both channels regardless of its configured destination.
        if channelCount > 2 || routing.hasNonDefaultRouting {
            let routeTracks = tracks.values.map { track in
                (
                    // Channel maps must be applied on the source node after a
                    // multi-channel connection. TimePitch stays mono and cannot
                    // carry a device-width channel map.
                    node: track.memoryPlayer.sourceNode as AVAudioNode,
                    format: track.sourceFormat,
                    destination: OutputRoutingStore.destination(for: track.groupID, snapshot: routing)
                )
            }

            var allRoutes = routeTracks
            if !routeTracks.isEmpty, let announcementSource {
                if announcementSource.sourceNode.engine == nil {
                    engine.attach(announcementSource.sourceNode)
                }
                allRoutes.append((
                    node: announcementSource.sourceNode as AVAudioNode,
                    format: announcementSource.format,
                    destination: OutputRoutingStore.guideDestination(snapshot: routing)
                ))
            }

            if OutputRoutingManager.applyChannelMapRouting(
                engine: engine,
                tracks: allRoutes,
                outputChannelCount: max(channelCount, 2)
            ) {
                // The callout node is now routed directly with the track nodes.
                isAnnouncementPlayerWired = true
                return
            }
        }

        connectTracksToMasterMixer()
    }

    func connectTracksToMasterMixer() {
        restoreFullOutputGain()

        engine.disconnectNodeOutput(engine.mainMixerNode)
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: outputFormat)

        for track in tracks.values {
            connectTrackToMasterMixer(track)
        }
        isAnnouncementPlayerWired = false
        wireAnnouncementPlayerIfNeeded()
    }

    private func connectTrackToMasterMixer(_ track: TrackState) {
        engine.disconnectNodeOutput(track.memoryPlayer.sourceNode)
        engine.disconnectNodeOutput(track.timePitchNode)
        OutputRoutingManager.clearChannelMap(on: track.memoryPlayer.sourceNode)
        OutputRoutingManager.clearChannelMap(on: track.timePitchNode)
        engine.connect(track.memoryPlayer.sourceNode, to: track.timePitchNode, format: track.sourceFormat)
        engine.connect(track.timePitchNode, to: masterMixer, format: track.sourceFormat)
    }

    private func restoreFullOutputGain() {
        masterMixer.outputVolume = 1
        engine.mainMixerNode.outputVolume = 1
    }

    private func outputChannelCount(for routing: OutputRoutingSnapshot) -> Int {
        let deviceCount = AudioOutputDeviceService.channelCount(for: routing.deviceUID)
        return max(routing.channelCount, deviceCount, 2)
    }
}
