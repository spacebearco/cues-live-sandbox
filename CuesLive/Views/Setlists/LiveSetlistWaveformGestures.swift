import SwiftUI

/// Tap seeks; drag is left to the enclosing scroll view for panning.
/// Every tap reports its time; the setlist decides what a tap inside a section does
/// (`LivePlaybackView.handleWaveformClick`).
struct WaveformSeekGestureModifier: ViewModifier {
    let isEnabled: Bool
    let contentWidth: CGFloat
    let window: LiveLaneWindow
    let onSeek: (TimeInterval) -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .contentShape(Rectangle())
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded { event in
                            onSeek(window.time(at: event.location.x, width: contentWidth))
                        }
                )
        } else {
            content
        }
    }
}
