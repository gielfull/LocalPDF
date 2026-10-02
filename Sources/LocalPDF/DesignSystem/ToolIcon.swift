import SwiftUI

/// A tool's SF Symbol on a rounded square filled with its category tint, as used by
/// tool tiles, suggestions and the result sheet.
struct ToolIcon: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: .rect(cornerRadius: size * 0.26))
            .accessibilityHidden(true)
    }
}
