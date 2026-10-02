import Foundation
import PDFKit

/// Protect PDF: encrypts with an open password and optional permission limits, using
/// AES-256 (PDF 2.0's revision 6 security handler) through qpdf. Everything else in the
/// file (forms, structure, attachments) is kept as is; an existing encryption is replaced.
public struct ProtectOperation: PDFOperation {
    public static let tool: ToolID = .protect

    public struct Options: Codable, Sendable, Hashable {
        /// Needed to open the file. Must not be empty; an empty one throws `.writeFailed`
        /// (naming the output file), since `PDFEngineError` has no dedicated case.
        public var userPassword: String = ""
        /// Needed to change permissions; defaults to `userPassword` when nil or empty.
        /// When it equals `userPassword`, opening the file grants every permission, so the
        /// `allow…` limits only bind when the two passwords differ.
        public var ownerPassword: String? = nil
        public var allowPrinting: Bool = true
        public var allowCopying: Bool = true
        public var allowEditing: Bool = true
        public init() {}
    }

    public init() {}

    public func run(_ inputs: [InputFile], options: Options,
                    progress: @Sendable (Double) -> Void) async throws -> [OutputFile] {
        try Job.forEach(inputs, reportingTo: progress) { input, reporter, directory in
            let output = directory.reserve(OutputName.make(.protect, from: input.url))
            guard !options.userPassword.isEmpty else { throw PDFEngineError.writeFailed(output.url) }

            // PDFKit vets the input and the password, so errors match every other tool.
            let source = try DocumentIO.open(input)
            try reporter.update(0.2)
            let scratch = directory.scratchURL(extension: "pdf")
            defer { try? FileManager.default.removeItem(at: scratch) }
            let pdf = try QPDF.open(input, orRewriteOf: source, at: scratch)
            try reporter.update(0.4)

            let ownerPassword = options.ownerPassword.flatMap { $0.isEmpty ? nil : $0 } ?? options.userPassword
            var writeOptions = QPDF.WriteOptions()
            writeOptions.encryption = .aes256(
                userPassword: options.userPassword, ownerPassword: ownerPassword,
                permissions: Self.permissions(for: options))
            do {
                try pdf.write(to: output.url, writeOptions)
            } catch {
                throw PDFEngineError.writeFailed(output.url)
            }
            return [output]
        }
    }

    /// `PDFAccessPermissions` bits for the three switches. Accessibility extraction (screen
    /// readers) is always granted, as the PDF spec recommends.
    private static func permissions(for options: Options) -> UInt {
        var bits = PDFAccessPermissions.allowsContentAccessibility.rawValue
        if options.allowPrinting {
            bits |= PDFAccessPermissions.allowsLowQualityPrinting.rawValue
                | PDFAccessPermissions.allowsHighQualityPrinting.rawValue
        }
        if options.allowCopying {
            bits |= PDFAccessPermissions.allowsContentCopying.rawValue
        }
        if options.allowEditing {
            bits |= PDFAccessPermissions.allowsDocumentChanges.rawValue
                | PDFAccessPermissions.allowsDocumentAssembly.rawValue
                | PDFAccessPermissions.allowsCommenting.rawValue
                | PDFAccessPermissions.allowsFormFieldEntry.rawValue
        }
        return bits
    }
}
