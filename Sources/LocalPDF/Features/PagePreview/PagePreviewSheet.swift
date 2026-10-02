import SwiftUI

/// A large, zoomable look at one page, to check it's the right one before acting on it.
/// ← / → step through the same pages the grid shows; Space or Esc closes, like Quick Look.
struct PagePreviewSheet: View {
    @State private var controller: PagePreviewController
    @Environment(\.dismiss) private var dismiss

    init(request: PagePreviewRequest) {
        _controller = State(initialValue: PagePreviewController(request: request))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) { controls.padding(.bottom, 16) }
        }
        .frame(minWidth: 560, idealWidth: 760, minHeight: 600, idealHeight: 880)
        .background(.background.secondary)
        .background { closeShortcut }
        .onAppear(perform: open)
        .onDisappear(perform: close)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Page \(controller.sourcePageNumber)")
                    .font(.headline)
                    .contentTransition(.numericText(value: Double(controller.sourcePageNumber)))
                Text(controller.request.file.name)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .animation(.snappy, value: controller.position)
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var content: some View {
        if controller.document != nil {
            PDFPreviewView(controller: controller) { dismiss() }
        } else {
            ProgressView()
        }
    }

    /// Floating glass controls: page stepper and zoom, with their keyboard shortcuts.
    private var controls: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    iconButton("Previous Page", "chevron.left", .leftArrow, modifiers: [],
                               enabled: controller.canGoBack, action: controller.goBack)
                    Text("\(controller.position + 1) of \(controller.pageCount)")
                        .font(.callout.weight(.medium))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(controller.position)))
                        .animation(.snappy, value: controller.position)
                        .frame(minWidth: 64)
                    iconButton("Next Page", "chevron.right", .rightArrow, modifiers: [],
                               enabled: controller.canGoForward, action: controller.goForward)
                }
                .padding(4)
                .glassEffect(.regular, in: .capsule)

                HStack(spacing: 2) {
                    iconButton("Zoom Out", "minus.magnifyingglass", "-", action: controller.zoomOut)
                    iconButton("Fit Page", "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", "0",
                               enabled: !controller.isFitted, action: controller.fit)
                    iconButton("Zoom In", "plus.magnifyingglass", "=", action: controller.zoomIn)
                }
                .padding(4)
                .glassEffect(.regular, in: .capsule)
            }
        }
    }

    private func iconButton(
        _ title: String, _ systemImage: String, _ key: KeyEquivalent,
        modifiers: EventModifiers = .command, enabled: Bool = true, action: @escaping () -> Void
    ) -> some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .controlSize(.large)
            .frame(width: 34, height: 30)
            .keyboardShortcut(key, modifiers: modifiers)
            .disabled(!enabled)
            .help(title)
    }

    /// Space closes the preview, as it does Quick Look. A zero-size button carries the
    /// shortcut for when focus is outside the page; once the page has focus, PDFView
    /// would scroll on Space instead, so `PDFPreviewView` closes from there itself.
    private var closeShortcut: some View {
        Button("Close Preview") { dismiss() }
            .keyboardShortcut(.space, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }

    // MARK: File access

    @State private var isAccessing = false

    private func open() {
        isAccessing = controller.request.file.url.startAccessingSecurityScopedResource()
        controller.load()
    }

    private func close() {
        if isAccessing {
            controller.request.file.url.stopAccessingSecurityScopedResource()
            isAccessing = false
        }
    }
}
