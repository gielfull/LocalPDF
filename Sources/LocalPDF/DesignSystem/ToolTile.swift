import PDFEngine
import SwiftUI

/// One tool on the home grid: a glass card tinted with its category color.
/// Place tiles inside a `GlassEffectContainer` so neighboring glass blends correctly.
struct ToolTile: View {
    let tool: ToolDescriptor
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    ToolIcon(systemImage: tool.systemImage, tint: tool.tint)
                    Spacer(minLength: 0)
                    if !tool.isAvailable {
                        SoonBadge()
                    }
                }
                Text(tool.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(tool.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect(cornerRadius: Self.radius))
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.tint(tool.tint.opacity(isHovering ? 0.22 : 0.08)).interactive(),
            in: .rect(cornerRadius: Self.radius)
        )
        .opacity(tool.isAvailable ? 1 : 0.62)
        .scaleEffect(isHovering ? 1.015 : 1)
        .animation(.snappy(duration: 0.18), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tool.title)
        .accessibilityValue(tool.isAvailable ? "" : "Coming soon")
        .accessibilityHint(tool.summary)
        .accessibilityAddTraits(.isButton)
    }

    private static let radius: CGFloat = 18
}
