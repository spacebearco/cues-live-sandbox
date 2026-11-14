import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension Color {
    func darkened(sRGBBy factor: Double) -> Color {
        #if canImport(AppKit)
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return self }
        return Color(
            .sRGB,
            red: clamped(Double(color.redComponent) * factor),
            green: clamped(Double(color.greenComponent) * factor),
            blue: clamped(Double(color.blueComponent) * factor),
            opacity: Double(color.alphaComponent)
        )
        #elseif canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return self }
        return Color(
            .sRGB,
            red: clamped(Double(red) * factor),
            green: clamped(Double(green) * factor),
            blue: clamped(Double(blue) * factor),
            opacity: Double(alpha)
        )
        #else
        return self
        #endif
    }

    /// Mixes the color toward white by `amount` (0 = unchanged, 1 = white), keeping its hue.
    func lightened(sRGBToward amount: Double) -> Color {
        func mix(_ component: Double) -> Double {
            clamped(component + (1 - component) * amount)
        }

        #if canImport(AppKit)
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return self }
        return Color(
            .sRGB,
            red: mix(Double(color.redComponent)),
            green: mix(Double(color.greenComponent)),
            blue: mix(Double(color.blueComponent)),
            opacity: Double(color.alphaComponent)
        )
        #elseif canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return self }
        return Color(
            .sRGB,
            red: mix(Double(red)),
            green: mix(Double(green)),
            blue: mix(Double(blue)),
            opacity: Double(alpha)
        )
        #else
        return self
        #endif
    }

    /// Text color that stays readable on top of this color: near-black on light
    /// fills (white, gray, yellow) and white on dark ones.
    var readableTextColor: Color {
        prefersDarkText ? Color.black.opacity(0.85) : .white
    }

    /// True when dark text contrasts better than white on this color.
    var prefersDarkText: Bool {
        // Crossover where black and white text have equal WCAG contrast.
        (relativeLuminance ?? 0) > 0.179
    }

    /// WCAG relative luminance (0 = black, 1 = white), or `nil` if unresolvable.
    var relativeLuminance: Double? {
        guard let (red, green, blue) = sRGBComponents else { return nil }
        func linear(_ component: Double) -> Double {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private var sRGBComponents: (Double, Double, Double)? {
        #if canImport(AppKit)
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return (Double(color.redComponent), Double(color.greenComponent), Double(color.blueComponent))
        #elseif canImport(UIKit)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return (Double(red), Double(green), Double(blue))
        #else
        return nil
        #endif
    }

    private func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
