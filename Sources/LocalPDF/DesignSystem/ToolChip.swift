import PDFEngine
import SwiftUI

/// A compact glass button for a tool, used by "Continue with…" and smart suggestions.
/// Place chips inside a `GlassEffectContainer`.
struct ToolChip: View {
    let tool: ToolDescriptor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ToolIcon(systemImage: tool.systemImage, tint: tool.tint, size: 24)
                Text(tool.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .fixedSize()
                if !tool.isAvailable {
                    SoonBadge()
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(tool.tint.opacity(0.1)).interactive(), in: .capsule)
        .accessibilityLabel(tool.title)
        .accessibilityValue(tool.isAvailable ? "" : "Coming soon")
    }
}
