import Foundation
import PDFKit

/// Rotate PDF: rotates pages of every input by a multiple of 90°.
public struct RotateOperation: PDFOperation {
    public static let tool: ToolID = .rotate

    public struct Options: Codable, Sendable, Hashable {
        /// Clockwise degrees: 90, 180 or 270 (negative values rotate counter-clockwise).
        /// Other values snap to the nearest multiple of 90.
        public var degrees: Int = 90
        /// `PageRange` syntax, or `nil` for all pages.
        public var pages: PageSelection = nil
        public init() {}
    }

    public init() {}

    public func run(_ inputs: [InputFile], options: Options,
                    progress: @Sendable (Double) -> Void) async throws -> [OutputFile] {
        try Job.forEach(inputs, reportingTo: progress) { input, reporter, directory in
            let source = try DocumentIO.open(input)
            let selected = try PageSelectionResolver.indices(options.pages, pageCount: source.pageCount)

            var assembler = DocumentAssembler()
            for index in 0..<source.pageCount {
                try reporter.update(Double(index) / Double(source.pageCount))
                let original = try source.requirePage(at: index, of: input.url)
                let page = assembler.append(copyOf: original)
                if selected.contains(index) {
                    page.rotation = PageGeometry.normalized(original.rotation + options.degrees)
                }
            }
            assembler.copyOutline(of: source)
            assembler.copyAttributes(of: source)

            let output = directory.reserve(OutputName.make(.rotate, from: input.url))
            try assembler.write(to: output.url)
            return [output]
        }
    }
}
