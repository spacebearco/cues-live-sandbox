import SwiftData
import SwiftUI

/// Edit mode's Me Time switch: all audio goes to one dedicated output while it is on.
/// Right-click picks the device and the output pair. Hidden in Show mode.
struct MeTimeToolbarToggle: View {
    let isOn: Bool
    let onToggle: () -> Void
    /// Called after the device or pair changes, so a running Me Time moves to it.
    let onOutputChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SetlistPlayMode.storageKey) private var playMode = SetlistPlayMode.defaultMode
    @AppStorage(MeTimeSettings.startChannelKey) private var startChannel = MeTimeSettings.defaultStartChannel
    @AppStorage(MeTimeSettings.deviceKey) private var deviceUID = ""

    private var mainDeviceUID: String? {
        OutputRoutingStore.config(in: modelContext).selectedDeviceUID
    }

    /// Devices Me Time can move to: every output except the one the show plays from.
    private var otherDevices: [AudioOutputDevice] {
        AudioOutputDeviceService.availableDevices().filter { $0.id != mainDeviceUID }
    }

    private var stereoPairs: [OutputDestination] {
        let channelCount = otherDevices.first { $0.id == deviceUID }?.channelCount
            ?? AudioOutputDeviceService.channelCount(for: mainDeviceUID)
        return OutputRoutingStore.destinations(for: channelCount).stereo
    }

    var body: some View {
        if playMode == .edit {
            Toggle(isOn: Binding(get: { isOn }, set: { _ in onToggle() })) {
                Label("Me Time", systemImage: "headphones")
            }
            .tint(AppColors.accent)
            .help("Me Time: send all audio to its own output. Right-click to pick the device and output.")
            .contextMenu { outputMenu }
            .onChange(of: deviceUID) { _, uid in
                // Another device starts on its first pair; the show's device on the pair past the mains.
                startChannel = uid.isEmpty ? MeTimeSettings.defaultStartChannel : 1
                onOutputChanged()
            }
            .onChange(of: startChannel) { _, _ in
                onOutputChanged()
            }
        }
    }

    @ViewBuilder
    private var outputMenu: some View {
        Picker("Me Time Device", selection: $deviceUID) {
            Text("Same Device as the Show").tag("")
            ForEach(otherDevices) { device in
                Text(device.name).tag(device.id)
            }
        }
        .pickerStyle(.inline)

        Picker("Me Time Output", selection: $startChannel) {
            ForEach(stereoPairs) { pair in
                if case .stereoPair(let start) = pair {
                    Text("Outputs \(pair.displayLabel)").tag(start)
                }
            }
        }
        .pickerStyle(.inline)
    }
}
