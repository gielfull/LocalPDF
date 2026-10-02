import PDFEngine
import SwiftUI

/// The generic tool screen: files or pages on the canvas, options in the inspector, one
/// primary action. iLovePDF's "upload → options → button" as "drop → inspector → ⌘↩".
struct ToolView: View {
    @Bindable var session: ToolSession
    let onAddFiles: () -> Void

    @AppStorage("showsToolOptions") private var showsInspector = true
    @AppStorage("toolOptionsWidth") private var inspectorWidth = Self.defaultInspectorWidth

    private static let defaultInspectorWidth = 320.0
    private static let inspectorWidths = 280.0...420.0

    var body: some View {
        // The options column is laid out here rather than with `.inspector`: on macOS 27 a
        // detail-column inspector starts full height (under the toolbar) and switches to
        // below the toolbar once its divider is dragged. As part of the detail content it
        // always sits below the toolbar, like the canvas beside it.
        HStack(spacing: 0) {
            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .top) {
                    if let notice = session.notice {
                        NoticeBanner(text: notice) { session.notice = nil }
                    }
                }
            if showsInspector {
                HStack(spacing: 0) {
                    ColumnResizeHandle(
                        width: $inspectorWidth, range: Self.inspectorWidths,
                        defaultWidth: Self.defaultInspectorWidth
                    )
                    ToolInspector(session: session)
                        .frame(width: inspectorWidth.clamped(to: Self.inspectorWidths))
                }
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.snappy(duration: 0.25), value: showsInspector)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Options", systemImage: "sidebar.trailing") {
                    showsInspector.toggle()
                }
                .help(showsInspector ? "Hide Options" : "Show Options")
            }
        }
        .sheet(item: $session.pagePreview) { request in
            PagePreviewSheet(request: request)
        }
        .quickLookPreview($session.quickLookURL)
        .navigationTitle(session.descriptor.title)
        .navigationSubtitle(subtitle)
    }

    @ViewBuilder
    private var canvas: some View {
        if session.files.isEmpty {
            ToolEmptyState(tool: session.descriptor, onDrop: add, onAdd: onAddFiles)
        } else {
            Group {
                switch session.canvas {
                case .files(let reorderable):
                    FileGridCanvas(session: session, reorderable: reorderable, onAddFiles: onAddFiles)
                case .pageSelection:
                    PageSelectionCanvas(session: session)
                case .organize:
                    OrganizeCanvas(session: session)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                add(urls.filter(\.isFileURL))
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                // One-file tools show their file here, with Replace… and Remove; file
                // grids already have a remove button on every card.
                if !session.descriptor.allowsMultipleInputs {
                    LoadedFileBar(session: session, onReplace: onAddFiles)
                }
            }
        }
    }

    private var subtitle: String {
        switch session.files.count {
        case 0: ""
        case 1: session.files[0].name
        default: "\(session.files.count) files"
        }
    }

    private func add(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task { await session.add(urls) }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// A dismissible note above the canvas, e.g. about files that weren't added.
private struct NoticeBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}
