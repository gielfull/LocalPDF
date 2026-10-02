import Foundation
import PDFKit

/// Compress PDF: reduces file size. Never returns a file larger than its input;
/// if compression doesn't help, the output is a byte-identical copy.
///
/// Two pipelines run and the smaller result wins:
/// 1. Images: PDFKit re-encodes them as JPEG and caps their resolution (not at `.less`), and
///    `.extreme` also re-renders text-free image pages. qpdf's structural pass
///    (`StructureOptimizer`) then runs over PDFKit's output.
/// 2. Structure only: the same qpdf pass over the original file, which keeps everything in
///    it (forms, tags, attachments) and is what shrinks text-heavy files.
///
/// An encrypted input stays encrypted: same open password, same permission flags. When the
/// structure-only result wins, the original encryption is kept exactly. When the image
/// result wins, it is re-encrypted with AES-256; the owner password can't be recovered, so
/// that output gets a random one, and Unlock still lifts the restrictions for anyone who
/// can open the file. An input opened with its owner password only gets the structure-only
/// pass: its open password and restrictions can't be reproduced (`QPDF.Encryption.matching`).
public struct CompressOperation: PDFOperation {
    public static let tool: ToolID = .compress

    public enum Level: String, Codable, Sendable, Hashable, CaseIterable {
        /// Smallest file, visibly lower image quality. Pages without text (scans, photos)
        /// are re-rendered as 100 dpi JPEGs when that is smaller.
        case extreme
        /// Good balance; the default.
        case recommended
        /// Highest quality, modest savings.
        case less
    }

    public struct Options: Codable, Sendable, Hashable {
        public var level: Level = .recommended
        public init() {}
    }

    public init() {}

    public func run(_ inputs: [InputFile], options: Options,
                    progress: @Sendable (Double) -> Void) async throws -> [OutputFile] {
        try Job.forEach(inputs, reportingTo: progress) { input, reporter, directory in
            let source = try DocumentIO.open(input)
            let output = directory.reserve(OutputName.make(.compress, from: input.url))
            var scratchFiles: [URL] = []
            defer { for url in scratchFiles { try? FileManager.default.removeItem(at: url) } }
            func scratch() -> URL {
                let url = directory.scratchURL(extension: "pdf")
                scratchFiles.append(url)
                return url
            }

            // 1. Images, then structure.
            let imagePass = scratch()
            try Self.writeImagePass(of: source, input: input, level: options.level, to: imagePass,
                                    reporter: &reporter)
            // Unencrypted, PDFKit's own output is a fallback should qpdf fail on it. Encrypted, it
            // can only compete when its protection can be reproduced (see `matching`); otherwise
            // only the structure-only pass, which keeps the original encryption, is a candidate.
            var candidates: [URL] = source.isEncrypted ? [] : [imagePass]
            if let encryption = QPDF.Encryption.matching(source, input: input),
               let optimized = Self.structurePass(try? QPDF(url: imagePass), level: options.level,
                                                  encryption: encryption, to: scratch()) {
                candidates.append(optimized)
            }
            try reporter.update(0.75)

            // 2. Structure only, over the original file.
            if let optimized = Self.structurePass(try? QPDF.open(input), level: options.level,
                                                  encryption: .keep, to: scratch()) {
                candidates.append(optimized)
            }
            try reporter.update(0.95)

            let best = candidates
                .filter { Self.opens($0, like: source, input: input) }
                .min { (DocumentIO.fileSize($0) ?? .max) < (DocumentIO.fileSize($1) ?? .max) }
            if let best {
                try? FileManager.default.removeItem(at: output.url)
                do {
                    try FileManager.default.moveItem(at: best, to: output.url)
                } catch {
                    throw PDFEngineError.writeFailed(output.url)
                }
            }
            try Self.keepOriginalIfNotSmaller(output: output.url, original: input.url)
            return [output]
        }
    }

    /// The image pipeline, written unencrypted to `url`: every page copied into a fresh
    /// document (PDFKit writes an unmodified document back byte for byte, ignoring the image
    /// options), text-free image pages rasterized at `.extreme`.
    private static func writeImagePass(of source: PDFDocument, input: InputFile, level: Level,
                                       to url: URL, reporter: inout ProgressReporter) throws {
        var assembler = DocumentAssembler()
        var scratchDocuments: [PDFDocument] = []
        for index in 0..<source.pageCount {
            try reporter.update(0.6 * Double(index) / Double(source.pageCount))
            let page = try source.requirePage(at: index, of: input.url)
            if level == .extreme, let rasterized = ImagePageRasterizer.replacement(for: page) {
                scratchDocuments.append(rasterized.scratch)
                assembler.append(rasterized.page, standingInFor: page)
            } else {
                assembler.append(copyOf: page)
            }
        }
        assembler.copyOutline(of: source)
        assembler.copyAttributes(of: source)

        var writeOptions: [PDFDocumentWriteOption: Any] = [:]
        if level != .less {
            writeOptions[.saveImagesAsJPEGOption] = true
            writeOptions[.optimizeImagesForScreenOption] = true
        }
        try withExtendedLifetime(scratchDocuments) {
            try assembler.write(to: url, options: writeOptions)
        }
    }

    /// `pdf` through `StructureOptimizer` into `url`; nil when qpdf couldn't read or write it,
    /// in which case the other candidates (or the original) are used.
    private static func structurePass(_ pdf: QPDF?, level: Level, encryption: QPDF.Encryption,
                                      to url: URL) -> URL? {
        guard let pdf else { return nil }
        do {
            try StructureOptimizer.optimize(pdf, to: url, level: level, encryption: encryption)
            return url
        } catch {
            return nil
        }
    }

    /// Whether PDFKit opens `url` (with the input's password) with all of `source`'s pages:
    /// a last check before a qpdf result replaces the user's file.
    private static func opens(_ url: URL, like source: PDFDocument, input: InputFile) -> Bool {
        guard let document = PDFDocument(url: url) else { return false }
        if document.isLocked {
            guard let password = input.password, document.unlock(withPassword: password) else { return false }
        }
        return document.pageCount == source.pageCount
    }

    /// Replaces `output` with a copy of `original` unless it is strictly smaller.
    private static func keepOriginalIfNotSmaller(output: URL, original: URL) throws {
        guard let originalSize = DocumentIO.fileSize(original) else { return }
        if let outputSize = DocumentIO.fileSize(output), outputSize < originalSize { return }
        do {
            try? FileManager.default.removeItem(at: output)
            try FileManager.default.copyItem(at: original, to: output)
        } catch {
            throw PDFEngineError.writeFailed(output)
        }
    }
}
