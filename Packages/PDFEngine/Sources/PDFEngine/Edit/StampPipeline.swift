import CoreGraphics
import Foundation
import PDFKit

/// The stamp pipeline shared by Add Page Numbers and Watermark.
///
/// Every page is redrawn into a new `CGPDFContext` with `drawPDFPage`, which embeds the
/// original content as a vector form XObject, so text stays selectable and searchable;
/// the stamp is drawn after it (`.overContent`) or before it (`.underContent`).
///
/// Media and crop boxes keep the page's own coordinates and `/Rotate` is restored
/// afterwards, so annotations, links and bookmarks (carried over by `DocumentAssembler`)
/// still line up. The stamp itself is drawn in reader space, so it lands where the
/// reader sees it whatever the page's rotation.
enum StampPipeline {
    enum Layer {
        case overContent, underContent
    }

    /// Draws the stamp for page `index` (0-based) in reader space: origin at the bottom-left
    /// of the crop box as displayed, y up, `size` being the displayed crop box.
    typealias Stamp = (_ context: CGContext, _ size: CGSize, _ index: Int) -> Void

    /// Writes `source` to `destination` with `stamp` drawn on the pages in `pages`.
    /// Progress goes through `progress`'s current item.
    static func stamp(
        _ source: PDFDocument, sourceURL: URL, pages: Set<Int>, layer: Layer,
        to destination: URL, scratch: URL, progress: inout ProgressReporter,
        stamp: Stamp
    ) throws {
        defer { try? FileManager.default.removeItem(at: scratch) }
        try render(source, sourceURL: sourceURL, pages: pages, layer: layer,
                   to: scratch, destination: destination, progress: &progress, stamp: stamp)

        guard let stamped = PDFDocument(url: scratch), stamped.pageCount == source.pageCount else {
            throw PDFEngineError.writeFailed(destination)
        }
        var assembler = DocumentAssembler()
        for index in 0..<source.pageCount {
            guard let original = source.page(at: index), let page = stamped.page(at: index) else {
                throw PDFEngineError.writeFailed(destination)
            }
            assembler.append(page, standingInFor: original)
        }
        assembler.copyOutline(of: source)
        assembler.copyAttributes(of: source)
        try progress.update(0.95)
        try assembler.write(to: destination)
    }

    private static func render(
        _ source: PDFDocument, sourceURL: URL, pages: Set<Int>, layer: Layer,
        to scratch: URL, destination: URL, progress: inout ProgressReporter, stamp: Stamp
    ) throws {
        var defaultBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(scratch as CFURL, mediaBox: &defaultBox, nil) else {
            throw PDFEngineError.writeFailed(destination)
        }
        let pageCount = source.pageCount
        for index in 0..<pageCount {
            try progress.update(0.9 * Double(index) / Double(pageCount))
            guard let page = source.page(at: index), let pdfPage = page.pageRef else {
                throw PDFEngineError.cannotOpen(sourceURL)
            }
            let mediaBox = pdfPage.getBoxRect(.mediaBox)
            let cropBox = pdfPage.getBoxRect(.cropBox)
            let pageInfo: [CFString: Any] = [
                kCGPDFContextMediaBox: mediaBox.pdfBoxData,
                kCGPDFContextCropBox: cropBox.pdfBoxData,
            ]
            let geometry = PageGeometry(box: cropBox, rotation: page.rotation)
            let isStamped = pages.contains(index)

            context.beginPDFPage(pageInfo as CFDictionary)
            if isStamped, layer == .underContent {
                draw(stamp, index: index, geometry: geometry, in: context)
            }
            context.saveGState()
            context.drawPDFPage(pdfPage)
            context.restoreGState()
            if isStamped, layer == .overContent {
                draw(stamp, index: index, geometry: geometry, in: context)
            }
            context.endPDFPage()
        }
        context.closePDF()
    }

    private static func draw(_ stamp: Stamp, index: Int, geometry: PageGeometry, in context: CGContext) {
        context.saveGState()
        context.concatenate(geometry.readerToPage)
        stamp(context, geometry.readerSize, index)
        context.restoreGState()
    }
}
