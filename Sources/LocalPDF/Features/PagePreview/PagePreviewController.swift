import Observation
import PDFKit

/// Drives the preview's `PDFView`: which page is showing and how far it's zoomed.
///
/// The preview builds its own in-memory document from copies of the requested pages, in
/// the requested order and rotation, so PDFView's own navigation (arrow keys, scrolling)
/// walks exactly the pages the grid shows. Nothing here is ever saved.
@Observable
final class PagePreviewController {
    let request: PagePreviewRequest
    /// Position in `request.items` of the page on screen.
    private(set) var position: Int
    /// True while the page is scaled to fit the view, false once the user zooms.
    private(set) var isFitted = true
    private(set) var document: PDFDocument?

    @ObservationIgnored weak var pdfView: PDFView?

    init(request: PagePreviewRequest) {
        self.request = request
        self.position = request.start
    }

    var pageCount: Int { request.items.count }
    var canGoBack: Bool { position > 0 }
    var canGoForward: Bool { position < pageCount - 1 }

    /// The page number in the original file, for the title.
    var sourcePageNumber: Int {
        request.items.indices.contains(position) ? request.items[position].sourceIndex + 1 : 1
    }

    /// Opens the file and assembles the preview document. Call while holding the file's
    /// security-scoped access; PDFKit reads page content lazily from the file.
    func load() {
        guard document == nil, let source = PDFDocument(url: request.file.url) else { return }
        if source.isLocked, let password = request.file.password {
            source.unlock(withPassword: password)
        }
        let preview = PDFDocument()
        for item in request.items {
            guard let page = source.page(at: item.sourceIndex)?.copy() as? PDFPage else { continue }
            page.rotation = (page.rotation + item.rotation) % 360
            preview.insert(page, at: preview.pageCount)
        }
        document = preview
    }

    func goBack() { go(to: position - 1) }
    func goForward() { go(to: position + 1) }

    func zoomIn() { pdfView?.zoomIn(nil) }
    func zoomOut() { pdfView?.zoomOut(nil) }

    func fit() {
        guard let pdfView else { return }
        pdfView.autoScales = true
        isFitted = true
    }

    private func go(to newPosition: Int) {
        guard (0..<pageCount).contains(newPosition), let page = document?.page(at: newPosition) else { return }
        pdfView?.go(to: page)
    }

    // MARK: Reports from the PDFView

    func pdfViewDidChangePage(to index: Int) {
        position = index
    }

    func pdfViewDidChangeScale(autoScales: Bool) {
        isFitted = autoScales
    }
}
