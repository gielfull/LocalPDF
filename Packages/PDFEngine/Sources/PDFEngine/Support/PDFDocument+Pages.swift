import Foundation
import PDFKit

extension PDFDocument {
    /// The page at `index`, or `.cannotOpen(url)` when PDFKit can't produce it (a damaged
    /// page tree reports more pages than it can deliver).
    func requirePage(at index: Int, of url: URL) throws -> PDFPage {
        guard let page = page(at: index) else { throw PDFEngineError.cannotOpen(url) }
        return page
    }
}
