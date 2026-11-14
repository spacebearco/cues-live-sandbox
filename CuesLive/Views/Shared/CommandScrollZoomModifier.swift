import SwiftUI

#if os(macOS)
import AppKit

/// Zooms a timeline with Cmd + scroll wheel on macOS, reported like a pinch so
/// views reuse their `MagnificationGesture` handlers. A burst of scroll events is
/// one gesture: `onChanged` receives the scale since the burst began, and
/// `onEnded` fires once the wheel has been idle briefly.
private struct CommandScrollZoomModifier: ViewModifier {
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    @State private var monitor = ScrollZoomMonitor()

    func body(content: Content) -> some View {
        content
            .onHover { monitor.isHovering = $0 }
            .onAppear {
                monitor.onChanged = onChanged
                monitor.onEnded = onEnded
                monitor.start()
            }
            .onDisappear { monitor.stop() }
    }
}

@MainActor
private final class ScrollZoomMonitor {
    /// Scale change per point of scroll; a trackpad flick or a few wheel notches double the zoom.
    private static let scalePerPoint: Double = 0.006
    /// A mouse wheel reports whole lines; this converts them to roughly trackpad points.
    private static let pointsPerLine: Double = 8
    private static let idleEndDelay: Duration = .milliseconds(180)

    var isHovering = false
    var onChanged: (CGFloat) -> Void = { _ in }
    var onEnded: () -> Void = {}

    private var eventMonitor: Any?
    private var scale: CGFloat = 1
    private var isZooming = false
    private var endTask: Task<Void, Never>?

    func start() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, event.modifierFlags.contains(.command) else { return event }
            let delta = event.hasPreciseScrollingDeltas
                ? Double(event.scrollingDeltaY)
                : Double(event.scrollingDeltaY) * Self.pointsPerLine
            let consumed = MainActor.assumeIsolated { self.zoom(byScrollDelta: delta) }
            return consumed ? nil : event
        }
    }

    func stop() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
        finishZoom()
    }

    /// Handles one Cmd + scroll event. Returns true when it was over this view
    /// and should not also scroll.
    private func zoom(byScrollDelta delta: Double) -> Bool {
        guard isHovering else { return false }
        guard delta != 0 else { return true }

        if !isZooming {
            isZooming = true
            scale = 1
        }
        scale *= CGFloat(exp(delta * Self.scalePerPoint))
        onChanged(scale)

        endTask?.cancel()
        endTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.idleEndDelay)
            guard !Task.isCancelled else { return }
            self?.finishZoom()
        }
        return true
    }

    private func finishZoom() {
        endTask?.cancel()
        endTask = nil
        guard isZooming else { return }
        isZooming = false
        scale = 1
        onEnded()
    }
}
#endif

extension View {
    /// Cmd + scroll wheel zoom on macOS (no-op elsewhere), with pinch-style callbacks.
    func commandScrollZoom(
        onChanged: @escaping (CGFloat) -> Void,
        onEnded: @escaping () -> Void
    ) -> some View {
        #if os(macOS)
        modifier(CommandScrollZoomModifier(onChanged: onChanged, onEnded: onEnded))
        #else
        self
        #endif
    }
}
