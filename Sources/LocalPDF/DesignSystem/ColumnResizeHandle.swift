import SwiftUI

/// The divider on the leading edge of a trailing column. A hairline to look at, with a
/// wider invisible strip to grab: dragging it left widens the column, within `range`.
/// Double-clicking restores `defaultWidth`, as with Finder's column dividers.
struct ColumnResizeHandle: View {
    @Binding var width: Double
    let range: ClosedRange<Double>
    let defaultWidth: Double

    @State private var widthAtDragStart: Double?

    var body: some View {
        Rectangle()
            .fill(.separator)
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .overlay {
                Color.clear
                    .frame(width: 9)
                    .contentShape(.rect)
                    .pointerStyle(.columnResize)
                    .gesture(drag)
                    .onTapGesture(count: 2) { width = defaultWidth }
            }
            .accessibilityElement()
            .accessibilityLabel("Options width")
            .accessibilityValue("\(Int(width)) points")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: width = min(width + 20, range.upperBound)
                case .decrement: width = max(width - 20, range.lowerBound)
                @unknown default: break
                }
            }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                let start = widthAtDragStart ?? width
                widthAtDragStart = start
                width = min(max(start - value.translation.width, range.lowerBound), range.upperBound)
            }
            .onEnded { _ in widthAtDragStart = nil }
    }
}
