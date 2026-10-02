import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import PDFEngine

extension Fixtures {
    /// Ways to break a PDF's file structure while leaving its objects intact.
    enum Damage {
        /// Cut off just before the cross-reference table: no xref, no trailer, no
        /// `startxref`, as after an interrupted download or save. PDFKit can't open it.
        case truncated
        /// Every in-use cross-reference entry points at the wrong byte offset. PDFKit
        /// refuses the file (or, depending on the bytes, opens it with empty pages).
        case wrongOffsets
    }

    /// `pdf(name, pages:)` with `damage` done to its file structure.
    func damagedPDF(_ damage: Damage, _ name: String = "report", pages: Int) throws -> URL {
        let url = try pdf(name, pages: pages)
        // Latin-1 maps every byte to one character and back, so binary streams survive.
        let text = try #require(String(data: Data(contentsOf: url), encoding: .isoLatin1))
        let xref = try #require(text.range(of: "\nxref\n"))
        let damaged: String
        switch damage {
        case .truncated:
            damaged = String(text[..<xref.lowerBound])
        case .wrongOffsets:
            damaged = String(text[..<xref.upperBound]) + text[xref.upperBound...].replacingOccurrences(
                of: #"\d{10} 00000 n"#, with: "0000000999 00000 n", options: .regularExpression)
        }
        try #require(damaged.data(using: .isoLatin1)).write(to: url)
        return url
    }

    /// `pages` pages of justified body text, like a report or a book chapter. Page k starts
    /// with "Chapter k". Alternates two fonts so more than one is embedded.
    func textHeavyPDF(_ name: String = "book", pages: Int) throws -> URL {
        let url = directory.appending(path: "\(name).pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try #require(CGContext(url as CFURL, mediaBox: &box, nil))
        let words = """
            lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor \
            incididunt ut labore et dolore magna aliqua enim ad minim veniam quis nostrud \
            exercitation ullamco laboris nisi aliquip ex ea commodo consequat
            """.split(separator: " ")
        var generator = SplitMix64(seed: 7)
        for page in 1...pages {
            var body = "Chapter \(page)\n\n"
            for _ in 0..<550 {
                body += words[Int(generator.next() % UInt64(words.count))] + " "
            }
            let font = CTFontCreateWithName((page.isMultiple(of: 2) ? "Times New Roman" : "Helvetica") as CFString,
                                            11, nil)
            let attributed = NSAttributedString(string: body, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
            ])
            let framesetter = CTFramesetterCreateWithAttributedString(attributed)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0),
                                                 CGPath(rect: box.insetBy(dx: 72, dy: 72), transform: nil), nil)
            context.beginPDFPage(nil)
            CTFrameDraw(frame, context)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }
}
