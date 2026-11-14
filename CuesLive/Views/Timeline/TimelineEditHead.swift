import SwiftUI

/// The edit head: where a click lands, and where Split cuts, Paste lands and Play starts. One
/// line through the ruler and every lane, with a marker in the ruler. It is always shown, playing
/// or stopped, in its own color so it never reads as the red playhead. Pinned to the viewport
/// like the playhead, so scrolling never lays it out again.
struct TimelineEditHead: View {
    @Environment(\.displayScale) private var displayScale

    var model: TimelineHorizontalScrollModel
    let time: TimeInterval
    let duration: TimeInterval
    let contentWidth: CGFloat
    let viewportWidth: CGFloat
    let height: CGFloat

    private static let markerWidth: CGFloat = 11
    private static let markerHeight: CGFloat = 8

    var body: some View {
        let offset = model.offset
        Canvas { context, size in
            let rawX = TimelineLayout.xPosition(
                for: max(0, time),
                duration: max(duration, 0.001),
                contentWidth: contentWidth
            ) - offset
            let x = displayScale > 0 ? (rawX * displayScale).rounded() / displayScale : rawX.rounded()
            guard x >= -Self.markerWidth, x <= size.width + Self.markerWidth else { return }

            context.fill(
                Path(CGRect(x: x - 0.5, y: 0, width: 1, height: size.height)),
                with: .color(AppColors.Timeline.editHead)
            )
            var marker = Path()
            marker.move(to: CGPoint(x: x - Self.markerWidth / 2, y: 0))
            marker.addLine(to: CGPoint(x: x + Self.markerWidth / 2, y: 0))
            marker.addLine(to: CGPoint(x: x, y: Self.markerHeight))
            marker.closeSubpath()
            context.fill(marker, with: .color(AppColors.Timeline.editHead))
        }
        .frame(width: viewportWidth, height: height, alignment: .topLeading)
        .allowsHitTesting(false)
        .animation(nil, value: offset)
    }
}
