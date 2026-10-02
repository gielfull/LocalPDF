import Foundation
import PDFKit

/// Remove Pages: drops the selected pages and keeps the rest, in order.
public struct RemovePagesOperation: PDFOperation {
    public static let tool: ToolID = .removePages

    public struct Options: Codable, Sendable, Hashable {
        /// `PageRange` syntax. Removing every page is an error.
        public var pages: String = ""
        public init() {}
    }

    public init() {}

    public func run(_ inputs: [InputFile], options: Options,
                    progress: @Sendable (Double) -> Void) async throws -> [OutputFile] {
        let input = try DocumentIO.singleInput(inputs)
        return try Job.run(reportingTo: progress) { reporter, directory in
            let source = try DocumentIO.open(input)
            let removed = Set(try PageRange(parsing: options.pages, pageCount: source.pageCount).indices)
            guard removed.count < source.pageCount else {
                throw PDFEngineError.invalidPageRange(options.pages)
            }

            var assembler = DocumentAssembler()
            for index in 0..<source.pageCount where !removed.contains(index) {
                try reporter.update(Double(index) / Double(source.pageCount))
                assembler.append(copyOf: try source.requirePage(at: index, of: input.url))
            }
            assembler.copyOutline(of: source)
            assembler.copyAttributes(of: source)

            let output = directory.reserve(OutputName.make(.removePages, from: input.url))
            try assembler.write(to: output.url)
            return [output]
        }
    }
}
