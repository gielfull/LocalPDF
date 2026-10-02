import CoreGraphics
import Foundation
import PDFKit

/// OCR PDF: makes scanned pages searchable and selectable, entirely on the Mac with Vision.
///
/// Each page that needs it is rendered at 300 dpi (`RecognitionImage`) and read with Vision
/// (`TextRecognizer`). The page is then rewritten the way the stamp pipeline does it: the
/// original content is drawn unchanged with `drawPDFPage`, so vector art and images stay as
/// they were, and the recognized text goes on top in invisible text mode, fitted to the
/// scanned words (`InvisibleTextLayer`). Pages are recognized one at a time, so memory is
/// bounded by one page image.
///
/// Pages that are skipped (they already have text, or Vision finds none) are copied as they
/// are. Media and crop boxes, rotation, annotations, links, bookmarks and document attributes
/// carry over. An encrypted input comes out unencrypted, like the other page-rewriting tools.
public struct OCROperation: PDFOperation {
    public static let tool: ToolID = .ocr

    public enum Accuracy: String, Codable, Sendable, Hashable, CaseIterable {
        /// Vision's document recognition: the best results, in every supported language.
        case accurate
        /// Quicker, rougher recognition, for Latin-script languages only (see
        /// `supportedLanguages(for: .fast)`). Choosing any other language runs `.accurate`.
        case fast
    }

    public struct Options: Codable, Sendable, Hashable {
        /// Languages to recognize, as BCP-47 tags from `supportedLanguages()`, most likely
        /// first. Empty (the default) lets Vision detect the language. Tags Vision doesn't
        /// support are ignored; when none is left, detection is automatic.
        public var languages: [String] = []
        /// Leave pages that already have extractable text untouched: born-digital pages, or
        /// pages OCR'd before. Off, every page gets a text layer, even over existing text.
        public var skipPagesWithText: Bool = true
        /// `.accurate` by default.
        public var accuracy: Accuracy = .accurate
        public init() {}
    }

    public init() {}

    /// Vision's recognition languages for `accuracy` as BCP-47 tags ("en-US", "zh-Hans"),
    /// in Vision's order, for a language picker.
    public static func supportedLanguages(for accuracy: Accuracy = .accurate) -> [String] {
        TextRecognizer.supported(for: accuracy).map(TextRecognizer.identifier(for:))
    }

    public func run(_ inputs: [InputFile], options: Options,
                    progress: @Sendable (Double) -> Void) async throws -> [OutputFile] {
        let recognizer = TextRecognizer(options: options)
        return try await Job.forEach(inputs, reportingTo: progress) { input, reporter, directory in
            let source = try DocumentIO.open(input)
            let lines = try await Self.recognize(
                source, url: input.url, recognizer: recognizer,
                skipPagesWithText: options.skipPagesWithText, progress: &reporter)

            let output = directory.reserve(OutputName.make(.ocr, from: input.url))
            try Self.write(source, sourceURL: input.url, lines: lines, to: output.url,
                           scratch: directory.scratchURL(extension: "pdf"), progress: &reporter)
            return [output]
        }
    }

    // MARK: - Recognition

    /// The recognized lines of every page that gets a text layer, by 0-based page index.
    private static func recognize(
        _ source: PDFDocument, url: URL, recognizer: TextRecognizer,
        skipPagesWithText: Bool, progress: inout ProgressReporter
    ) async throws -> [Int: [RecognizedLine]] {
        var result: [Int: [RecognizedLine]] = [:]
        let pageCount = source.pageCount
        for index in 0..<pageCount {
            try progress.update(0.9 * Double(index) / Double(pageCount))
            let page = try source.requirePage(at: index, of: url)
            if skipPagesWithText, hasText(page) { continue }
            guard let pdfPage = page.pageRef else { throw PDFEngineError.cannotOpen(url) }

            let geometry = PageGeometry(box: pdfPage.getBoxRect(.cropBox), rotation: page.rotation)
            let size = geometry.readerSize
            guard size.width >= 1, size.height >= 1 else { continue }
            guard let image = RecognitionImage.render(pdfPage, geometry: geometry) else {
                throw PDFEngineError.recognitionFailed(url)
            }
            let lines = try await recognizer.recognize(image, readerSize: size, of: url)
            if !lines.isEmpty { result[index] = lines }
        }
        return result
    }

    private static func hasText(_ page: PDFPage) -> Bool {
        page.string?.contains { !$0.isWhitespace } == true
    }

    // MARK: - Writing

    /// Writes `source` to `destination`, the pages in `lines` with their text layer and
    /// every other page copied unchanged.
    private static func write(
        _ source: PDFDocument, sourceURL: URL, lines: [Int: [RecognizedLine]],
        to destination: URL, scratch: URL, progress: inout ProgressReporter
    ) throws {
        defer { try? FileManager.default.removeItem(at: scratch) }
        let recognized = lines.keys.sorted()
        var layered: PDFDocument?
        if !recognized.isEmpty {
            try renderLayers(source, sourceURL: sourceURL, pages: recognized, lines: lines,
                             to: scratch, destination: destination, progress: &progress)
            guard let document = PDFDocument(url: scratch), document.pageCount == recognized.count else {
                throw PDFEngineError.writeFailed(destination)
            }
            layered = document
        }

        var assembler = DocumentAssembler()
        var nextLayered = 0
        for index in 0..<source.pageCount {
            let original = try source.requirePage(at: index, of: sourceURL)
            if lines[index] != nil, let page = layered?.page(at: nextLayered) {
                assembler.append(page, standingInFor: original)
                nextLayered += 1
            } else {
                assembler.append(copyOf: original)
            }
        }
        assembler.copyOutline(of: source)
        assembler.copyAttributes(of: source)
        try progress.update(0.95)
        // The copied pages reference the scratch document until the output is written.
        try withExtendedLifetime(layered) {
            try assembler.write(to: destination)
        }
    }

    /// One scratch page per index in `pages`: the original content, then the invisible text.
    /// Boxes keep the page's own coordinates, as in `StampPipeline`; `/Rotate` is restored by
    /// `DocumentAssembler.append(_:standingInFor:)`.
    private static func renderLayers(
        _ source: PDFDocument, sourceURL: URL, pages: [Int], lines: [Int: [RecognizedLine]],
        to scratch: URL, destination: URL, progress: inout ProgressReporter
    ) throws {
        var defaultBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(scratch as CFURL, mediaBox: &defaultBox, nil) else {
            throw PDFEngineError.writeFailed(destination)
        }
        for (position, index) in pages.enumerated() {
            try progress.update(0.9 + 0.05 * Double(position) / Double(pages.count))
            let page = try source.requirePage(at: index, of: sourceURL)
            guard let pdfPage = page.pageRef else { throw PDFEngineError.cannotOpen(sourceURL) }
            let cropBox = pdfPage.getBoxRect(.cropBox)
            let pageInfo: [CFString: Any] = [
                kCGPDFContextMediaBox: pdfPage.getBoxRect(.mediaBox).pdfBoxData,
                kCGPDFContextCropBox: cropBox.pdfBoxData,
            ]
            let geometry = PageGeometry(box: cropBox, rotation: page.rotation)

            context.beginPDFPage(pageInfo as CFDictionary)
            context.saveGState()
            context.drawPDFPage(pdfPage)
            context.restoreGState()
            context.saveGState()
            context.concatenate(geometry.readerToPage)
            InvisibleTextLayer.draw(lines[index] ?? [], in: context)
            context.restoreGState()
            context.endPDFPage()
        }
        context.closePDF()
    }
}
