import SwiftUI

/// A small rotary knob with its value beside it, for a track's gain or pan. Drag the knob up or
/// right to raise the value, click the number to type one (Return commits, Escape cancels), and
/// double-click the knob to reset.
struct TrackKnobField: View {
    let text: String
    /// Part of the arc (0…1 around the knob's 270° sweep) lit to show the value. Gain fills from
    /// the bottom of the range; pan fills from the center.
    let fill: ClosedRange<CGFloat>
    /// Where the pointer sits, 0…1 around the sweep.
    let pointer: CGFloat
    /// Drag distance in points (right and up are positive); `isFinal` on release.
    let onDrag: (CGFloat, _ isFinal: Bool) -> Void
    let onReset: () -> Void
    /// Returns `true` when the typed text was valid and applied.
    let onCommit: (String) -> Bool

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    private static let knobSize: CGFloat = 18
    private static let valueWidth: CGFloat = 28
    private static let height: CGFloat = 22
    private static let startAngle = 135.0
    private static let sweep = 270.0

    var body: some View {
        // A chip the height of the M and S buttons, so the mix row reads as one even row.
        HStack(spacing: 3) {
            knob
                .frame(width: Self.knobSize, height: Self.knobSize)
                .contentShape(Circle())
                .gesture(dragGesture)
                .onTapGesture(count: 2, perform: onReset)
            valueText
        }
        .padding(.horizontal, 3)
        .frame(height: Self.height)
        .background(AppColors.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var knob: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 1.5
            context.fill(Path(ellipseIn: CGRect(x: 2.5, y: 2.5, width: size.width - 5, height: size.height - 5)),
                         with: .color(AppColors.backgroundSecondary))
            context.stroke(arc(center: center, radius: radius, from: 0, to: 1),
                           with: .color(AppColors.separator), lineWidth: 2)
            if fill.upperBound - fill.lowerBound > 0.001 {
                context.stroke(arc(center: center, radius: radius, from: fill.lowerBound, to: fill.upperBound),
                               with: .color(AppColors.Mixer.meterLevel), lineWidth: 2)
            }
            let angle = Angle.degrees(Self.startAngle + Self.sweep * Double(pointer)).radians
            var line = Path()
            line.move(to: center)
            line.addLine(to: CGPoint(x: center.x + cos(angle) * (radius - 3), y: center.y + sin(angle) * (radius - 3)))
            context.stroke(line, with: .color(AppColors.textPrimary), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }

    private func arc(center: CGPoint, radius: CGFloat, from start: CGFloat, to end: CGFloat) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(Self.startAngle + Self.sweep * Double(start)),
            endAngle: .degrees(Self.startAngle + Self.sweep * Double(end)),
            clockwise: false
        )
        return path
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { drag in
                guard !isEditing else { return }
                onDrag(drag.translation.width - drag.translation.height, false)
            }
            .onEnded { drag in
                guard !isEditing else { return }
                onDrag(drag.translation.width - drag.translation.height, true)
            }
    }

    @ViewBuilder
    private var valueText: some View {
        Group {
            if isEditing {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .focusEffectDisabled()
                    .onSubmit(commit)
                    #if os(macOS)
                    .onExitCommand { isEditing = false }
                    #endif
                    .onChange(of: isFocused) { _, focused in
                        if !focused, isEditing { commit() }
                    }
            } else {
                Text(text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        draft = text
                        isEditing = true
                        isFocused = true
                    }
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
        .foregroundStyle(AppColors.textPrimary)
        .frame(width: Self.valueWidth, height: Self.height, alignment: .center)
    }

    private func commit() {
        guard isEditing else { return }
        isEditing = false
        _ = onCommit(draft.trimmingCharacters(in: .whitespaces))
    }
}
