import CoreGraphics
import Foundation
import ImageIO
import PDFKit

/// Extreme compression's image pass: a page with no text whose images are heavy (a scan,
/// a photo page) is redrawn as a single lower-resolution JPEG.
///
/// This stands in for the system "Reduce File Size" Quartz filter, which the engine can't
/// use: `QuartzFilter` lives in Quartz.framework and its header imports Cocoa, i.e. AppKit.
///
/// Pages with text are never rasterized, so text stays selectable. The replacement keeps
/// the page's crop box geometry; `DocumentAssembler.append(_:standingInFor:)` carries over
/// rotation, annotations, links and bookmarks.
enum ImagePageRasterizer {
    static let resolution: CGFloat = 100
    static let quality = 0.5

    /// A one-page scratch document holding `page` rasterized, or `nil` when the page has
    /// text, has no images, or the JPEG wouldn't be smaller than the images it replaces.
    /// Keep the scratch document alive until the output has been written.
    static func replacement(for page: PDFPage) -> (scratch: PDFDocument, page: PDFPage)? {
        let text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard text.isEmpty, let pdfPage = page.pageRef else { return nil }
        let imageBytes = PDFImageXObjects.encodedSize(of: pdfPage)
        guard imageBytes > 0 else { return nil }

        let cropBox = pdfPage.getBoxRect(.cropBox)
        let scale = resolution / 72
        let width = Int((cropBox.width * scale).rounded(.up))
        let height = Int((cropBox.height * scale).rounded(.up))
        guard let canvas = ImageEncoding.whiteCanvas(width: width, height: height) else { return nil }
        canvas.scaleBy(x: CGFloat(width) / cropBox.width, y: CGFloat(height) / cropBox.height)
        canvas.translateBy(x: -cropBox.minX, y: -cropBox.minY)
        // Unrotated and without annotations: those stay live on the replacement page.
        canvas.drawPDFPage(pdfPage)

        guard let bitmap = canvas.makeImage(),
              let jpeg = ImageEncoding.data(bitmap, type: .jpeg, quality: quality),
              jpeg.count < imageBytes,
              // Decoded through ImageIO, the JPEG's own bytes go into the PDF (DCTDecode).
              let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let data = NSMutableData()
        var mediaBox = cropBox
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return nil }
        context.beginPDFPage(cropBox.pdfPageInfo)
        context.draw(image, in: cropBox)
        context.endPDFPage()
        context.closePDF()

        guard let scratch = PDFDocument(data: data as Data), let newPage = scratch.page(at: 0) else {
            return nil
        }
        return (scratch, newPage)
    }
}
