import AppKit
import SwiftUI

/// File-level tools: a grid of file cards. Merge and Images to PDF reorder by drag with
/// macOS 27's `reorderable()` / `reorderContainer`, because their order is the output order.
struct FileGridCanvas: View {
    @Bindable var session: ToolSession
    let reorderable: Bool
    let onAddFiles: () -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 176, maximum: 200), spacing: 20)], spacing: 20) {
                ForEach(session.files) { file in
                    FileCard(
                        thumbnail: file.thumbnail, name: file.name, detail: file.detail,
                        isLocked: file.needsPassword,
                        position: reorderable ? (session.files.firstIndex(of: file) ?? 0) + 1 : nil
                    ) {
                        withAnimation(.snappy) { session.remove(file.id) }
                    }
                    .onTapGesture(count: 2) { session.preview(file) }
                    .contextMenu {
                        Button(file.kind == .image ? "Quick Look" : "Preview Pages", systemImage: "magnifyingglass") {
                            session.preview(file)
                        }
                        .disabled(file.needsPassword)
                        Button("Show in Finder", systemImage: "folder") {
                            NSWorkspace.shared.activateFileViewerSelecting([file.url])
                        }
                        Divider()
                        Button("Remove", systemImage: "minus.circle", role: .destructive) {
                            withAnimation(.snappy) { session.remove(file.id) }
                        }
                    }
                }
                .reorderable()

                if session.descriptor.allowsMultipleInputs {
                    AddFileCard(action: onAddFiles)
                }
            }
            .reorderContainer(for: SourceFile.self, isEnabled: reorderable) { difference in
                let target: SourceFile.ID? = switch difference.destination.position {
                case .before(let id): id
                case .end: nil
                }
                withAnimation(.snappy) { session.moveFiles(difference.sources, before: target) }
            }
            .padding(28)
        }
        .safeAreaInset(edge: .bottom) {
            if reorderable, session.files.count > 1 {
                CanvasHint(text: "Drag files to set the order")
            }
        }
    }
}

/// The trailing "+" card in a multi-file grid.
private struct AddFileCard: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .light))
                    .frame(width: 140, height: 170)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.separator, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    }
                Text("Add Files")
                    .font(.callout.weight(.medium))
                Text(" ")
                    .font(.caption)
            }
            .foregroundStyle(isHovering ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .padding(12)
            .frame(width: 176)
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("Add Files")
    }
}
