import SwiftData
import SwiftUI

/// Edit mode's Me Time switch: all audio goes to one dedicated output while it is on.
/// Right-click picks the output pair. Hidden in Show mode.
struct MeTimeToolbarToggle: View {
    let isOn: Bool
    let onToggle: () -> Void
    /// Called after the output pair changes, so a running Me Time moves to it.
    let onOutputChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SetlistPlayMode.storageKey) private var playMode = SetlistPlayMode.defaultMode
    @AppStorage(MeTimeSettings.startChannelKey) private var startChannel = MeTimeSettings.defaultStartChannel

    private var stereoPairs: [OutputDestination] {
        let uid = OutputRoutingStore.config(in: modelContext).selectedDeviceUID
        return OutputRoutingStore.destinations(for: AudioOutputDeviceService.channelCount(for: uid)).stereo
    }

    var body: some View {
        if playMode == .edit {
            Toggle(isOn: Binding(get: { isOn }, set: { _ in onToggle() })) {
                Label("Me Time", systemImage: "headphones")
            }
            .tint(AppColors.accent)
            .help("Me Time: send all audio to its own output. Right-click to pick the output.")
            .contextMenu {
                Picker("Me Time Output", selection: $startChannel) {
                    ForEach(stereoPairs) { pair in
                        if case .stereoPair(let start) = pair {
                            Text("Outputs \(pair.displayLabel)").tag(start)
                        }
                    }
                }
                .pickerStyle(.inline)
            }
            .onChange(of: startChannel) { _, _ in
                onOutputChanged()
            }
        }
    }
}
