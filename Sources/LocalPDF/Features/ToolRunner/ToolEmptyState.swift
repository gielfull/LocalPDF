import PDFEngine
import SwiftUI

/// A tool with no files yet: its icon and a drop zone worded for the tool.
struct ToolEmptyState: View {
    let tool: ToolDescriptor
    let onDrop: ([URL]) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ToolIcon(systemImage: tool.systemImage, tint: tool.tint, size: 64)
            DropZone(title: title, subtitle: tool.summary, onDrop: onDrop, onAdd: onAdd)
                .frame(maxWidth: 560)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        let isPDF = tool.acceptedInputs.contains(.pdf)
        switch (isPDF, tool.allowsMultipleInputs) {
        case (true, true): return "Drop PDF files here"
        case (true, false): return "Drop a PDF here"
        case (false, _): return "Drop images here"
        }
    }
}
