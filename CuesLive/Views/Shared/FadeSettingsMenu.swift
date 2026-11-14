import SwiftUI

/// Right-click menu for a Fade button: how long the fade takes, and whether a low-pass sweep
/// follows it. Both are remembered (`FadeButtonSettings`).
struct FadeSettingsMenu: View {
    @AppStorage(FadeButtonSettings.durationKey) private var fadeSeconds = FadeButtonSettings.defaultDuration
    @AppStorage(FadeButtonSettings.filterSweepKey) private var fadeSweepsFilter = true

    var body: some View {
        Picker("Fade Time", selection: $fadeSeconds) {
            ForEach(FadeButtonSettings.durationOptions, id: \.self) { seconds in
                Text(FadeButtonSettings.label(forSeconds: seconds)).tag(seconds)
            }
        }
        .pickerStyle(.inline)
        Divider()
        Toggle("Filter Sweep", isOn: $fadeSweepsFilter)
    }
}
