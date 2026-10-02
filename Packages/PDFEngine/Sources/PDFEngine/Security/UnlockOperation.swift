import Foundation
import PDFKit

/// Unlock PDF: writes an unencrypted copy. Files with an open password need
/// `InputFile.password`; permission-only restrictions are removed without one.
///
/// qpdf decrypts the file and writes it back otherwise unchanged (forms, structure and
/// attachments included). A file qpdf can't parse but PDFKit can is rebuilt with PDFKit.
public struct UnlockOperation: PDFOperation {
    public static let tool: ToolID = .unlock

    public struct Options: Codable, Sendable, Hashable {
        public init() {}
    }

    public init() {}

    public func run(_ inputs: [InputFile], options: Options,
                    progress: @Sendable (Double) -> Void) async throws -> [OutputFile] {
        try Job.forEach(inputs, reportingTo: progress) { input, reporter, directory in
            // PDFKit vets the input and the password, so errors match every other tool.
            let source = try DocumentIO.open(input)
            try reporter.update(0.2)
            let output = directory.reserve(OutputName.make(.unlock, from: input.url))
            let scratch = directory.scratchURL(extension: "pdf")
            defer { try? FileManager.default.removeItem(at: scratch) }
            let pdf = try QPDF.open(input, orRewriteOf: source, at: scratch)
            try reporter.update(0.4)

            var writeOptions = QPDF.WriteOptions()
            writeOptions.encryption = .remove
            do {
                try pdf.write(to: output.url, writeOptions)
            } catch {
                throw PDFEngineError.writeFailed(output.url)
            }
            return [output]
        }
    }
}
