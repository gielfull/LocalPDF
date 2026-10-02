import PDFEngine
import SwiftUI

/// Inside the drop zone after a drop: the files, then the suggested tools as chips.
struct StagedFilesView: View {
    let files: [SourceFile]
    let suggestions: [ToolID]
    let onPick: (ToolID) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: files.count == 1 ? "doc.fill" : "doc.on.doc.fill")
                    .foregroundStyle(.secondary)
                Text(summary)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("Clear", action: onClear)
                    .buttonStyle(.link)
            }
            .accessibilityElement(children: .combine)

            if suggestions.isEmpty {
                Text("None of the tools take these files yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    Label("Suggested", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    GlassEffectContainer(spacing: 8) {
                        FlowLayout(spacing: 8, centered: true) {
                            ForEach(suggestions, id: \.self) { tool in
                                ToolChip(tool: ToolCatalog.descriptor(for: tool)) { onPick(tool) }
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 6)
    }

    private var summary: String {
        let size = files.reduce(Int64(0)) { $0 + $1.byteCount }.formatted(.byteCount(style: .file))
        if files.count == 1, let file = files.first {
            return "\(file.name) · \(file.detail)"
        }
        return "\(files.count) files · \(size)"
    }
}
