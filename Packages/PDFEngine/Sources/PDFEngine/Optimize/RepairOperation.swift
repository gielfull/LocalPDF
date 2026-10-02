import Foundation
import PDFKit

/// Repair PDF: rebuilds a damaged file's structure so viewers can open it again.
///
/// qpdf reads the file in recovery mode (it reconstructs a broken or missing cross-reference
/// table and trailer by scanning the objects themselves) and writes a clean file: fresh
/// xref, object streams, every object renumbered. When qpdf can't read the file, or recovers
/// fewer pages than PDFKit sees, PDFKit's lenient parse is rewritten too and the result with
/// more pages wins. Either way the result must open in PDFKit with at least one page.
///
/// An encrypted input stays encrypted; it needs its password like any input. qpdf keeps the
/// file's own encryption. The PDFKit rewrite is re-encrypted (AES-256, same open password and
/// restrictions), except for an input opened with its owner password, whose protection can't
/// be reproduced: that rewrite is skipped rather than made with the wrong protection.
public struct RepairOperation: PDFOperation {
    public static let tool: ToolID = .repair

    public struct Options: Codable, Sendable, Hashable {
        public init() {}
    }

    public init() {}

    public func run(_ inputs: [InputFile], options: Options,
                    progress: @Sendable (Double) -> Void) async throws -> [OutputFile] {
        try Job.forEach(inputs, reportingTo: progress) { input, reporter, directory in
            let output = directory.reserve(OutputName.make(.repair, from: input.url))
            let pdfKitPages = Self.pdfKitPageCount(of: input)
            let qpdfResult = directory.scratchURL(extension: "pdf")
            let pdfKitResult = directory.scratchURL(extension: "pdf")
            defer {
                try? FileManager.default.removeItem(at: qpdfResult)
                try? FileManager.default.removeItem(at: pdfKitResult)
            }

            // 1. qpdf's reconstruction.
            var qpdfPages: Int?
            do {
                let pdf = try QPDF.open(input)
                try reporter.update(0.3)
                var writeOptions = QPDF.WriteOptions()
                writeOptions.generateObjectStreams = true
                try pdf.write(to: qpdfResult, writeOptions)
                qpdfPages = Self.openedPageCount(qpdfResult, input: input)
            } catch let failure as QPDF.Failure where failure.isPasswordError {
                let password = input.password ?? ""
                throw password.isEmpty ? PDFEngineError.passwordRequired(input.url)
                                       : PDFEngineError.wrongPassword(input.url)
            } catch is QPDF.Failure {
                // qpdf couldn't make sense of the file; PDFKit may still.
            }
            try reporter.update(0.7)

            // 2. PDFKit's lenient parse, rewritten, when qpdf failed or found fewer pages.
            var result = qpdfResult
            if (qpdfPages ?? 0) < max(pdfKitPages ?? 0, 1) {
                try? Self.rewriteWithPDFKit(input, to: pdfKitResult, scratch: directory.scratchURL(extension: "pdf"))
                let rewrittenPages = Self.openedPageCount(pdfKitResult, input: input)
                if (rewrittenPages ?? 0) > (qpdfPages ?? 0) { result = pdfKitResult }
            }
            guard Self.openedPageCount(result, input: input) != nil else {
                throw PDFEngineError.cannotOpen(input.url)
            }
            do {
                try FileManager.default.moveItem(at: result, to: output.url)
            } catch {
                throw PDFEngineError.writeFailed(output.url)
            }
            return [output]
        }
    }

    /// The pages PDFKit can actually deliver from the input, or nil when it can't open it.
    private static func pdfKitPageCount(of input: InputFile) -> Int? {
        guard let document = try? DocumentIO.open(input) else { return nil }
        return (0..<document.pageCount).count { document.page(at: $0) != nil }
    }

    /// The page count of `url` as PDFKit opens it (unlocked with the input's password), or
    /// nil when it doesn't open or has no pages.
    private static func openedPageCount(_ url: URL, input: InputFile) -> Int? {
        guard let document = PDFDocument(url: url) else { return nil }
        if document.isLocked, !(input.password.map { document.unlock(withPassword: $0) } ?? false) {
            return nil
        }
        return document.pageCount > 0 ? document.pageCount : nil
    }

    /// Copies every page PDFKit can read into a fresh document at `url`, re-applying the
    /// input's encryption (through qpdf, as AES-256) when it had any.
    /// - Throws: `.cannotOpen` for an encrypted input whose protection can't be reproduced
    ///   (opened with the owner password): an unprotected or wrongly protected copy would be
    ///   worse than no result.
    private static func rewriteWithPDFKit(_ input: InputFile, to url: URL, scratch: URL) throws {
        let source = try DocumentIO.open(input)
        var assembler = DocumentAssembler()
        for index in 0..<source.pageCount {
            guard let page = source.page(at: index) else { continue }
            assembler.append(copyOf: page)
        }
        guard assembler.pageCount > 0 else { throw PDFEngineError.cannotOpen(input.url) }
        assembler.copyOutline(of: source)
        assembler.copyAttributes(of: source)

        guard source.isEncrypted else {
            try assembler.write(to: url)
            return
        }
        guard let encryption = QPDF.Encryption.matching(source, input: input) else {
            throw PDFEngineError.cannotOpen(input.url)
        }
        defer { try? FileManager.default.removeItem(at: scratch) }
        try assembler.write(to: scratch)
        var writeOptions = QPDF.WriteOptions()
        writeOptions.encryption = encryption
        do {
            try QPDF(url: scratch).write(to: url, writeOptions)
        } catch {
            throw PDFEngineError.writeFailed(url)
        }
    }
}
