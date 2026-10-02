import SwiftUI

extension View {
    /// Fades and lifts a view into place `index` steps after `isVisible` turns on, so a
    /// list of results arrives one row at a time. With Reduce Motion it only fades.
    func staggeredAppear(index: Int, isVisible: Bool, step: Double = 0.05) -> some View {
        modifier(StaggeredAppear(index: index, isVisible: isVisible, step: step))
    }
}

private struct StaggeredAppear: ViewModifier {
    let index: Int
    let isVisible: Bool
    let step: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 8)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.97)
            .animation(
                .spring(duration: 0.45, bounce: 0.25).delay(Double(index) * step),
                value: isVisible
            )
    }
}
