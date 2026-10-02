import CoreGraphics

/// Renders a page for OCR: its crop box as the reader sees it (rotation applied), in
/// grayscale on white, at up to 300 dpi.
///
/// Annotations are left out; they stay live on the output page and aren't scanned text.
/// One page is rendered at a time and released before the next, so memory stays bounded
/// by the largest page, which `maximumPixels` caps (about 36 MB).
enum RecognitionImage {
    static let resolution: CGFloat = 300
    /// A Letter page at 300 dpi is 8.4 megapixels; posters get a lower resolution instead.
    static let maximumPixels: CGFloat = 36_000_000

    /// `pdfPage` drawn in reader space; `nil` for a degenerate page or out of memory.
    static func render(_ pdfPage: CGPDFPage, geometry: PageGeometry) -> CGImage? {
        let size = geometry.readerSize
        guard size.width >= 1, size.height >= 1 else { return nil }
        let area = size.width * size.height
        let scale = min(resolution / 72, (maximumPixels / area).squareRoot())
        let width = Int((size.width * scale).rounded())
        let height = Int((size.height * scale).rounded())

        guard width > 0, height > 0,
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
              )
        else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high

        context.scaleBy(x: CGFloat(width) / size.width, y: CGFloat(height) / size.height)
        context.concatenate(geometry.readerToPage.inverted())
        context.clip(to: geometry.box)
        context.drawPDFPage(pdfPage)
        return context.makeImage()
    }
}
