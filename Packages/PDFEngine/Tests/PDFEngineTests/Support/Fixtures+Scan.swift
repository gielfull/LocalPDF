import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import PDFEngine

/// Image-only PDFs for OCR: text rendered into a bitmap, so the PDF itself holds no text.
extension Fixtures {
    /// One line of text on a scanned page, in reader space (as displayed, origin bottom-left).
    struct ScanLine {
        let text: String
        /// The baseline's start, in points.
        let origin: CGPoint
        let fontSize: CGFloat
    }

    static let letter = CGSize(width: 612, height: 792)

    static let scanLines = [
        ScanLine(text: "LocalPDF OCR test 2026", origin: CGPoint(x: 72, y: 680), fontSize: 28),
        ScanLine(text: "The quick brown fox jumps over the lazy dog", origin: CGPoint(x: 72, y: 630), fontSize: 18),
    ]

    /// A PDF whose pages are bitmaps of `lines` rendered at `dpi`, like a scan, and shown
    /// upright once the page's `rotation` is applied. Pages listed in `textPages` (0-based)
    /// draw the lines as real text instead, like a born-digital page.
    func scannedPDF(
        _ name: String = "scan", pages: Int = 1, lines: [ScanLine] = Fixtures.scanLines,
        readerSize: CGSize = Fixtures.letter, rotation: Int = 0, dpi: CGFloat = 200,
        textPages: Set<Int> = []
    ) throws -> URL {
        let url = directory.appending(path: "\(name).pdf")
        let pageSize = rotation % 180 == 0 ? readerSize : CGSize(width: readerSize.height, height: readerSize.width)
        let geometry = PageGeometry(box: CGRect(origin: .zero, size: pageSize), rotation: rotation)
        let scan = try scanImage(lines, readerSize: readerSize, dpi: dpi)

        var box = CGRect(origin: .zero, size: pageSize)
        let context = try #require(CGContext(url as CFURL, mediaBox: &box, nil))
        for index in 0..<pages {
            context.beginPDFPage(nil)
            context.concatenate(geometry.readerToPage)
            if textPages.contains(index) {
                for line in lines {
                    drawText(line.text, at: line.origin, size: line.fontSize, in: context)
                }
            } else {
                context.draw(scan, in: CGRect(origin: .zero, size: readerSize))
            }
            context.endPDFPage()
        }
        context.closePDF()

        if rotation != 0 {
            try modify(url) { document in
                for index in 0..<document.pageCount { document.page(at: index)?.rotation = rotation }
            }
        }
        return url
    }

    /// `lines` in black on white, as a grayscale bitmap covering `readerSize` at `dpi`.
    func scanImage(_ lines: [ScanLine], readerSize: CGSize, dpi: CGFloat) throws -> CGImage {
        let scale = dpi / 72
        let context = try #require(CGContext(
            data: nil, width: Int(readerSize.width * scale), height: Int(readerSize.height * scale),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
        context.scaleBy(x: scale, y: scale)
        for line in lines {
            drawText(line.text, at: line.origin, size: line.fontSize, in: context)
        }
        return try #require(context.makeImage())
    }

    /// Where `word` is drawn among `lines`, in reader space: its typographic box.
    static func expectedBounds(of word: String, in lines: [ScanLine] = Fixtures.scanLines) throws -> CGRect {
        let line = try #require(lines.first { $0.text.contains(word) })
        let range = try #require(line.text.range(of: word))
        let prefix = String(line.text[..<range.lowerBound])
        let font = CTFontCreateWithName("Helvetica" as CFString, line.fontSize, nil)
        func width(_ text: String) -> CGFloat {
            let attributed = NSAttributedString(string: text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
            ])
            return CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed), nil, nil, nil)
        }
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        return CGRect(x: line.origin.x + width(prefix), y: line.origin.y - descent,
                      width: width(word), height: ascent + descent)
    }
}
