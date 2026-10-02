import CoreGraphics
import CQPDF
import Foundation
import Testing
@testable import PDFEngine

extension Fixtures {
    /// A letterhead page (a photo, a line of text in an embedded font) repeated `copies`
    /// times the way naive merge tools do it: each copy comes from a separate read of the
    /// file, so every page carries its own byte-identical image and font streams. (PDFKit's
    /// Merge shares them, so it can't make this fixture.)
    func duplicatedResourcesPDF(_ name: String = "letterheads", copies: Int) throws -> URL {
        let page = directory.appending(path: "\(name)-page.pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try #require(CGContext(page as CFURL, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.draw(try noiseImage(size: CGSize(width: 600, height: 400), seed: 3),
                     in: CGRect(x: 72, y: 450, width: 300, height: 200))
        drawText("Letterhead", at: CGPoint(x: 72, y: 700), size: 18, in: context)
        context.endPDFPage()
        context.closePDF()

        let url = directory.appending(path: "\(name).pdf")
        var output = qpdf_init()
        var sources: [qpdf_data?] = []
        defer {
            qpdf_cleanup(&output)
            for var source in sources { qpdf_cleanup(&source) }
        }
        try #require(qpdf_empty_pdf(output) == QPDF_SUCCESS)
        for _ in 0..<copies {
            let source = qpdf_init()
            sources.append(source)
            try #require(page.withUnsafeFileSystemRepresentation { qpdf_read(source, $0, nil) } == QPDF_SUCCESS)
            try #require(qpdf_add_page(output, source, qpdf_get_page_n(source, 0), QPDF_FALSE) == QPDF_SUCCESS)
        }
        // As in QPDF.write: orders this write's read of qpdf's global zlib level after the one
        // store to it, which parallel tests may be making right now.
        lpdf_qpdf_use_max_flate_level()
        let status = url.withUnsafeFileSystemRepresentation { path in
            qpdf_init_write(output, path) | qpdf_write(output)
        }
        try #require(status == QPDF_SUCCESS)
        return url
    }

    /// A hand-written PDF in the style of Ghostscript's output: every stream's `/Length` is an
    /// indirect object. Page k shows its own copy of a 64×64 RGB image; `contents[k]` picks
    /// which of two pixel patterns it holds, so equal patterns are byte-identical streams
    /// with identical dictionaries, and different ones differ only in their data.
    func indirectLengthPDF(_ name: String = "indirect-length", contents: [Int]) throws -> URL {
        var data = Data("%PDF-1.4\n%\u{E2}\u{E3}\u{CF}\u{D3}\n".utf8)
        var offsets: [Int: Int] = [:]
        func object(_ number: Int, _ body: Data) {
            offsets[number] = data.count
            data += Data("\(number) 0 obj\n".utf8) + body + Data("\nendobj\n".utf8)
        }
        func stream(_ number: Int, dictionary: String, bytes: Data) {
            object(number, Data("<< \(dictionary) /Length \(number + 1) 0 R >>\nstream\n".utf8)
                + bytes + Data("\nendstream".utf8))
            object(number + 1, Data("\(bytes.count)".utf8))
        }

        // Objects: 1 catalog, 2 page tree, then 6 per page: page, contents (+ length),
        // image (+ length), and one spare number to keep the arithmetic simple.
        let first = 3
        let pageNumbers = contents.indices.map { first + $0 * 6 }
        object(1, Data("<< /Type /Catalog /Pages 2 0 R >>".utf8))
        object(2, Data("<< /Type /Pages /Count \(contents.count) /Kids [\(pageNumbers.map { "\($0) 0 R" }.joined(separator: " "))] >>".utf8))
        for (index, pattern) in contents.enumerated() {
            let page = pageNumbers[index]
            object(page, Data("""
                << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents \(page + 1) 0 R \
                /Resources << /XObject << /Im0 \(page + 3) 0 R >> >> >>
                """.utf8))
            stream(page + 1, dictionary: "", bytes: Data("q 300 0 0 300 156 246 cm /Im0 Do Q".utf8))
            var generator = SplitMix64(seed: UInt64(pattern + 1))
            let pixels = Data((0..<64 * 64 * 3).map { _ in UInt8(truncatingIfNeeded: generator.next()) })
            stream(page + 3, dictionary: "/Type /XObject /Subtype /Image /Width 64 /Height 64 /ColorSpace /DeviceRGB /BitsPerComponent 8",
                   bytes: pixels)
            object(page + 5, Data("null".utf8))
        }

        let size = (offsets.keys.max() ?? 0) + 1
        let xref = data.count
        var table = "xref\n0 \(size)\n0000000000 65535 f \n"
        for number in 1..<size {
            table += offsets[number].map { String(format: "%010d 00000 n \n", $0) } ?? "0000000000 65535 f \n"
        }
        table += "trailer\n<< /Size \(size) /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n"
        data += Data(table.utf8)

        let url = directory.appending(path: "\(name).pdf")
        try data.write(to: url)
        return url
    }
}
