import SwiftUI

/// Right-click menu for a Fade button: how many bars the fade takes, where a fade-in starts
/// from, and whether a low-pass sweep follows it. Both are remembered (`FadeButtonSettings`).
struct FadeSettingsMenu: View {
    @AppStorage(FadeButtonSettings.barsKey) private var fadeBars = FadeButtonSettings.defaultBars
    @AppStorage(FadeButtonSettings.filterSweepKey) private var fadeSweepsFilter = true
    @AppStorage(FadeButtonSettings.entryBarsKey) private var entryBars = FadeButtonSettings.defaultEntryBars

    var body: some View {
        Picker("Fade Length", selection: $fadeBars) {
            ForEach(FadeButtonSettings.barOptions, id: \.self) { bars in
                Text(FadeButtonSettings.label(forBars: bars)).tag(bars)
            }
        }
        .pickerStyle(.inline)
        Picker("Fade In Starts", selection: $entryBars) {
            ForEach(FadeButtonSettings.entryBarOptions, id: \.self) { bars in
                Text(FadeButtonSettings.entryLabel(forBars: bars)).tag(bars)
            }
        }
        .pickerStyle(.inline)
        Divider()
        Toggle("Filter Sweep", isOn: $fadeSweepsFilter)
    }
}
