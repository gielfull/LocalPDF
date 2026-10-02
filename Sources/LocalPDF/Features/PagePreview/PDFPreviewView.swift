import PDFKit
import SwiftUI

/// A `PDFView` showing one page at a time, scaled to fit until the user zooms (pinch,
/// ⌘+ / ⌘−, or the preview's zoom buttons). Page and zoom changes report back to the
/// controller so the preview's controls stay in sync. Space closes it, like Quick Look.
struct PDFPreviewView: NSViewRepresentable {
    let controller: PagePreviewController
    let onClose: () -> Void

    func makeNSView(context: Context) -> PreviewPDFView {
        let view = PreviewPDFView()
        view.onClose = onClose
        view.displayMode = .singlePage
        view.displaysPageBreaks = true
        view.pageShadowsEnabled = true
        view.autoScales = true
        view.backgroundColor = .clear
        view.document = controller.document
        if let start = controller.document?.page(at: controller.position) {
            view.go(to: start)
        }
        controller.pdfView = view
        context.coordinator.observe(view)
        return view
    }

    func updateNSView(_ view: PreviewPDFView, context: Context) {
        view.onClose = onClose
        if view.document !== controller.document {
            view.document = controller.document
        }
    }

    /// PDFView scrolls on Space, so once it has focus (after a click on the page) Space
    /// never reaches the sheet's shortcut. It closes the preview here instead; every other
    /// key (arrows, Page Up/Down, ⌘+ / ⌘−) keeps PDFView's own handling.
    final class PreviewPDFView: PDFView {
        var onClose: (() -> Void)?

        override func keyDown(with event: NSEvent) {
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard event.charactersIgnoringModifiers == " ", modifiers.isEmpty, let onClose else {
                super.keyDown(with: event)
                return
            }
            // A held Space closes once; its repeats must not scroll the closing sheet.
            if !event.isARepeat { onClose() }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    final class Coordinator: NSObject {
        let controller: PagePreviewController

        init(controller: PagePreviewController) {
            self.controller = controller
        }

        /// Selector-based observers unregister themselves when the coordinator goes away.
        func observe(_ view: PDFView) {
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(pageChanged), name: .PDFViewPageChanged, object: view)
            center.addObserver(self, selector: #selector(scaleChanged), name: .PDFViewScaleChanged, object: view)
        }

        @objc private func pageChanged(_ notification: Notification) {
            guard let view = notification.object as? PDFView,
                  let page = view.currentPage, let index = view.document?.index(for: page) else { return }
            controller.pdfViewDidChangePage(to: index)
        }

        @objc private func scaleChanged(_ notification: Notification) {
            guard let view = notification.object as? PDFView else { return }
            controller.pdfViewDidChangeScale(autoScales: view.autoScales)
        }
    }
}
