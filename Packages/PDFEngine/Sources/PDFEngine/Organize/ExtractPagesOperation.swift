import Foundation
import PDFKit

/// Extract Pages: copies the selected pages into a new PDF (or one PDF per page).
public struct ExtractPagesOperation: PDFOperation {
    public static let tool: ToolID = .extractPages

    public struct Options: Codable, Sendable, Hashable {
        /// `PageRange` syntax; pages are emitted in the order typed.
        public var pages: String = ""
        /// One output file per extracted page instead of a single file.
        public var separateFiles: Bool = false
        public init() {}
    }

    public init() {}

    public func run(_ inputs: [InputFile], options: Options,
                    progress: @Sendable (Double) -> Void) async throws -> [OutputFile] {
        let input = try DocumentIO.singleInput(inputs)
        return try Job.run(reportingTo: progress) { reporter, directory in
            let source = try DocumentIO.open(input)
            let indices = try PageRange(parsing: options.pages, pageCount: source.pageCount).indices
            let groups = options.separateFiles ? indices.map { [$0] } : [indices]

            var outputs: [OutputFile] = []
            for (number, group) in groups.enumerated() {
                try reporter.update(Double(number) / Double(groups.count))
                var assembler = DocumentAssembler()
                for index in group {
                    assembler.append(copyOf: try source.requirePage(at: index, of: input.url))
                }
                assembler.copyOutline(of: source)
                assembler.copyAttributes(of: source)

                let fragment = PageSelectionResolver.nameFragment(for: group)
                let output = directory.reserve(OutputName.make(.extractPages, from: input.url, detail: fragment))
                try assembler.write(to: output.url)
                outputs.append(output)
            }
            return outputs
        }
    }
}
