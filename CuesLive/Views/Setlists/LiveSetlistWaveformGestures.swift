import SwiftUI

/// Tap seeks. Every tap reports its time; the setlist decides what a tap inside a section does
/// (`LivePlaybackView.handleWaveformClick`).
///
/// With `onScrub` set, a mouse drag on macOS moves the playhead with the pointer. A mouse drag
/// does not pan the setlist there (the trackpad and scroll wheel do), so nothing is taken from
/// the scroll view. On iPad a touch drag still pans, so there is no scrub.
struct WaveformSeekGestureModifier: ViewModifier {
    let isEnabled: Bool
    let contentWidth: CGFloat
    let window: LiveLaneWindow
    let onSeek: (TimeInterval) -> Void
    var onScrub: ((TimeInterval) -> Void)?

    /// Pointer travel before a press counts as a drag rather than a click.
    private static let scrubThreshold: CGFloat = 4

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .contentShape(Rectangle())
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded { event in
                            onSeek(time(atX: event.location.x))
                        }
                )
                .modifier(ScrubGesture(onScrub: onScrub, threshold: Self.scrubThreshold, time: time(atX:)))
        } else {
            content
        }
    }

    private func time(atX x: CGFloat) -> TimeInterval {
        window.time(at: min(max(0, x), contentWidth), width: contentWidth)
    }
}

private struct ScrubGesture: ViewModifier {
    let onScrub: ((TimeInterval) -> Void)?
    let threshold: CGFloat
    let time: (CGFloat) -> TimeInterval

    func body(content: Content) -> some View {
        #if os(macOS)
        if let onScrub {
            content.simultaneousGesture(
                DragGesture(minimumDistance: threshold)
                    .onChanged { drag in onScrub(time(drag.location.x)) }
            )
        } else {
            content
        }
        #else
        content
        #endif
    }
}
