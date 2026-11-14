import CoreGraphics
import CoreText
import Foundation

/// The song number and name above each lane. Drawn here rather than as SwiftUI text in the
/// strip, so the strip stays as light as it was, and so the name can stay pinned to the leading
/// edge of the viewport while its lane scrolls under it.
extension LiveSetlistLanePainter {
    private static let headerInset: CGFloat = 6
    private static let headerBaselineOffset: CGFloat = 6

    /// Draws `song`'s header above `lane`, both in view coordinates.
    func drawHeader(_ song: Song, above lane: CGRect, in rect: CGRect, context: CGContext) {
        let available = lane.width - Self.headerInset * 2
        guard available > 20, lane.maxX > rect.minX, lane.minX < rect.maxX else { return }

        let font = CTFontCreateUIFontForLanguage(song.isCurrent ? .emphasizedSystem : .system, 11, nil)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font as Any,
            kCTForegroundColorAttributeName: song.isCurrent ? scene.titleColor : scene.dimTitleColor,
        ]
        guard let text = CFAttributedStringCreate(
            nil,
            "\(song.index + 1)   \(song.title)" as CFString,
            attributes as CFDictionary
        ) else { return }
        let full = CTLineCreateWithAttributedString(text)
        let line = CTLineCreateTruncatedLine(full, Double(available), .end, nil) ?? full
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))

        // Pinned to the viewport's leading edge while the lane runs past it.
        let pinned = max(lane.minX, rect.minX) + Self.headerInset
        let x = min(pinned, lane.maxX - Self.headerInset - width)

        context.saveGState()
        // The canvas is flipped; text draws upright with a flipped text matrix.
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(x: x, y: lane.minY - Self.headerBaselineOffset)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
