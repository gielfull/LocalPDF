import PDFEngine
import SwiftUI

/// A tool whose descriptor isn't available yet: never a half-working screen.
struct ComingSoonView: View {
    let tool: ToolDescriptor
    let onBrowseTools: () -> Void

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: 14) {
                ToolIcon(systemImage: tool.systemImage, tint: tool.tint, size: 64)
                    .opacity(0.75)
                Text(tool.title)
            }
        } description: {
            Text("\(tool.summary)\nThis tool is coming soon.")
        } actions: {
            Button("Browse Available Tools", action: onBrowseTools)
                .buttonStyle(.glass)
        }
        .navigationTitle(tool.title)
    }
}
