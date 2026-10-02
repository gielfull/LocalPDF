import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Testing
@testable import PDFEngine

/// Reads outputs back, the way a user's PDF viewer would.
enum Inspect {
    /// Opens `url`, unlocking it with `password` when given.
    static func document(_ url: URL, password: String? = nil) throws -> PDFDocument {
        let document = try #require(PDFDocument(url: url))
        if let password { try #require(document.unlock(withPassword: password)) }
        return document
    }

    /// Each page's extractable text, whitespace-trimmed.
    static func texts(_ url: URL) throws -> [String] {
        let document = try document(url)
        return (0..<document.pageCount).map {
            document.page(at: $0)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    /// The texts of every output, one array per file.
    static func texts(_ outputs: [OutputFile]) throws -> [[String]] {
        try outputs.map { try texts($0.url) }
    }

    static func rotations(_ url: URL) throws -> [Int] {
        let document = try document(url)
        return (0..<document.pageCount).map { document.page(at: $0)?.rotation ?? -1 }
    }

    /// A page box as stored in the file, read with CoreGraphics rather than PDFKit.
    static func box(_ box: CGPDFBox, of url: URL, page: Int) throws -> CGRect {
        let document = try #require(CGPDFDocument(url as CFURL))
        let pdfPage = try #require(document.page(at: page + 1))
        return pdfPage.getBoxRect(box)
    }

    static func pixelSize(_ url: URL) throws -> CGSize {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return CGSize(width: image.width, height: image.height)
    }

    /// Uncached, unlike `URL.resourceValues`, so a file replaced after a read reports its new size.
    static func fileSize(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
        return try #require((attributes[.size] as? NSNumber)?.intValue)
    }

    /// Where `text` sits on `page`, in reader space (rotation applied, origin bottom-left),
    /// as a fraction of the displayed page size.
    static func relativeReaderPosition(of text: String, on page: PDFPage) throws -> CGPoint {
        let string = try #require(page.string)
        let range = (string as NSString).range(of: text)
        try #require(range.location != NSNotFound, "“\(text)” not on page")
        let selection = try #require(page.selection(for: range))
        // PDFKit's own page-to-display transform is the oracle, independent of the engine's.
        let toReader = page.transform(for: .cropBox)
        let reader = selection.bounds(for: page).applying(toReader)
        let readerSize = page.bounds(for: .cropBox).applying(toReader).size
        return CGPoint(x: reader.midX / readerSize.width, y: reader.midY / readerSize.height)
    }

    /// The color at `point` (fractions of the displayed page, origin bottom-left) when page
    /// `index` is rendered the way a viewer shows it.
    static func color(at point: CGPoint, of url: URL, page index: Int = 0) throws -> Swatch {
        let page = try #require(try document(url).page(at: index))
        let size = page.bounds(for: .cropBox).applying(page.transform(for: .cropBox)).size
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
            page.draw(with: .cropBox, to: context)
        }
        let x = min(Int(point.x * CGFloat(width)), width - 1)
        let row = height - 1 - min(Int(point.y * CGFloat(height)), height - 1) // memory is top-down
        let offset = (row * width + x) * 4
        return Swatch(red: pixels[offset], green: pixels[offset + 1], blue: pixels[offset + 2])
    }
}
