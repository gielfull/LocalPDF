import Foundation
import PDFKit

/// Split PDF: one input becomes several PDFs.
public struct SplitOperation: PDFOperation {
    public static let tool: ToolID = .split

    public enum Mode: Codable, Sendable, Hashable {
        /// Each comma-separated part of the text becomes one file: "1-3, 4-6, 7-" → 3 files.
        case customRanges(String)
        /// Fixed-size chunks of `n` pages; the last chunk may be shorter.
        case everyNPages(Int)
        /// One file per page.
        case eachPage
    }

    public struct Options: Codable, Sendable, Hashable {
        public var mode: Mode = .eachPage
        public init() {}
    }

    public init() {}

    public func run(_ inputs: [InputFile], options: Options,
                    progress: @Sendable (Double) -> Void) async throws -> [OutputFile] {
        let input = try DocumentIO.singleInput(inputs)
        return try Job.run(reportingTo: progress) { reporter, directory in
            let source = try DocumentIO.open(input)
            let groups = try Self.groups(for: options.mode, pageCount: source.pageCount)

            var outputs: [OutputFile] = []
            for (number, group) in groups.enumerated() {
                try reporter.update(Double(number) / Double(groups.count))
                var assembler = DocumentAssembler()
                for index in group {
                    assembler.append(copyOf: try source.requirePage(at: index, of: input.url))
                }
                assembler.copyOutline(of: source)
                assembler.copyAttributes(of: source)

                let fragment = PageSelectionResolver.nameFragment(for: group) ?? "part-\(number + 1)"
                let output = directory.reserve(OutputName.make(.split, from: input.url, detail: fragment))
                try assembler.write(to: output.url)
                outputs.append(output)
            }
            return outputs
        }
    }

    /// The 0-based page indices of each output file, in order.
    private static func groups(for mode: Mode, pageCount: Int) throws -> [[Int]] {
        switch mode {
        case .customRanges(let text):
            let groups = try text.split(separator: ",")
                .filter { !$0.allSatisfy(\.isWhitespace) }
                .map { try PageRange(parsing: String($0), pageCount: pageCount).indices }
            guard !groups.isEmpty else { throw PDFEngineError.invalidPageRange(text) }
            return groups
        case .everyNPages(let size):
            guard size >= 1 else { throw PDFEngineError.invalidPageRange(String(size)) }
            return stride(from: 0, to: pageCount, by: size).map { start in
                Array(start..<min(start + size, pageCount))
            }
        case .eachPage:
            return (0..<pageCount).map { [$0] }
        }
    }
}
