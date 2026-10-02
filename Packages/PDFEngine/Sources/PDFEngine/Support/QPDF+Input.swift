import Foundation
import PDFKit

extension QPDF {
    /// Opens `input` with its password. A password that fails is retried as none: for a file
    /// that opens without one (permission restrictions only), any other password is
    /// irrelevant, as in `DocumentIO.open`.
    static func open(_ input: InputFile) throws(Failure) -> QPDF {
        do {
            return try QPDF(url: input.url, password: input.password)
        } catch where error.isPasswordError && !(input.password ?? "").isEmpty {
            guard let withoutPassword = try? QPDF(url: input.url) else { throw error }
            return withoutPassword
        }
    }

    /// Opens `input` with qpdf or, when qpdf can't parse a file PDFKit could open, an
    /// unencrypted PDFKit rewrite of `document` (the opened input) saved at `scratch`.
    ///
    /// - Throws: `.writeFailed(scratch)` or `.cannotOpen` when the rewrite fails too.
    static func open(_ input: InputFile, orRewriteOf document: PDFDocument, at scratch: URL) throws -> QPDF {
        if let pdf = try? open(input) { return pdf }
        var assembler = DocumentAssembler()
        for index in 0..<document.pageCount {
            assembler.append(copyOf: try document.requirePage(at: index, of: input.url))
        }
        assembler.copyOutline(of: document)
        assembler.copyAttributes(of: document)
        try assembler.write(to: scratch)
        do {
            return try QPDF(url: scratch)
        } catch {
            throw PDFEngineError.cannotOpen(input.url)
        }
    }
}
