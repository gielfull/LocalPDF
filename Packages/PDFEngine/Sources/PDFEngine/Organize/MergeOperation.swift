import Foundation
import PDFKit

/// Merge PDF: concatenates the inputs, in the order given, into one PDF.
public struct MergeOperation: PDFOperation {
    public static let tool: ToolID = .merge

    public struct Options: Codable, Sendable, Hashable {
        /// Add one outline entry per source file, titled with its file name.
        public var addBookmarks: Bool = true
        public init() {}
    }

    public init() {}

    public func run(_ inputs: [InputFile], options: Options,
                    progress: @Sendable (Double) -> Void) async throws -> [OutputFile] {
        guard inputs.count >= 2 else {
            throw PDFEngineError.unsupportedInput(inputs.first?.url ?? DocumentIO.noInputURL)
        }
        return try Job.run(reportingTo: progress) { reporter, directory in
            // Open everything up front, so a missing password on the last file fails fast.
            let sources = try inputs.map(DocumentIO.open)
            let totalPages = sources.reduce(0) { $0 + $1.pageCount }
            var assembler = DocumentAssembler()
            var pagesDone = 0

            for (input, source) in zip(inputs, sources) {
                let firstPageIndex = assembler.pageCount
                for index in 0..<source.pageCount {
                    try reporter.update(Double(pagesDone) / Double(totalPages))
                    assembler.append(copyOf: try source.requirePage(at: index, of: input.url))
                    pagesDone += 1
                }
                // Each file's own bookmarks nest under its file-name entry, or stay top-level.
                if options.addBookmarks, let firstPage = assembler.document.page(at: firstPageIndex) {
                    let bookmark = PDFOutline()
                    bookmark.label = DocumentIO.stem(of: input.url)
                    bookmark.destination = Self.topOf(firstPage)
                    let root = assembler.rootOutline()
                    root.insertChild(bookmark, at: root.numberOfChildren)
                    assembler.copyOutline(of: source, under: bookmark)
                } else {
                    assembler.copyOutline(of: source)
                }
            }

            let output = directory.reserve(OutputName.make(.merge, from: inputs[0].url))
            try assembler.write(to: output.url)
            return [output]
        }
    }

    /// A destination at the top-left of `page` as the reader sees it.
    private static func topOf(_ page: PDFPage) -> PDFDestination {
        let geometry = PageGeometry(box: page.bounds(for: .cropBox), rotation: page.rotation)
        let topLeft = CGPoint(x: 0, y: geometry.readerSize.height).applying(geometry.readerToPage)
        return PDFDestination(page: page, at: topLeft)
    }
}
