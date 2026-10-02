import Foundation
import PDFKit

/// Organize PDF: rebuilds a document from an explicit page plan produced by the
/// page-grid UI (reorder, rotate, delete, duplicate, insert blank pages).
public struct OrganizeOperation: PDFOperation {
    public static let tool: ToolID = .organize

    /// One page of the output, in output order.
    public struct PageInstruction: Codable, Sendable, Hashable {
        /// 0-based page index in the input, or `nil` for a blank page sized like the
        /// previous output page (US Letter if it is the first).
        public var sourcePageIndex: Int?
        /// Extra clockwise rotation in degrees, a multiple of 90, added to the page's own.
        /// Other values snap to the nearest multiple of 90.
        public var additionalRotation: Int

        public init(sourcePageIndex: Int?, additionalRotation: Int = 0) {
            self.sourcePageIndex = sourcePageIndex
            self.additionalRotation = additionalRotation
        }
    }

    public struct Options: Codable, Sendable, Hashable {
        /// Must not be empty. A source index may appear more than once (duplicate page).
        public var pages: [PageInstruction] = []
        public init() {}
    }

    public init() {}

    private static let usLetter = CGSize(width: 612, height: 792)

    public func run(_ inputs: [InputFile], options: Options,
                    progress: @Sendable (Double) -> Void) async throws -> [OutputFile] {
        let input = try DocumentIO.singleInput(inputs)
        return try Job.run(reportingTo: progress) { reporter, directory in
            let source = try DocumentIO.open(input)
            // An empty plan or an out-of-range page is reported like a bad page range,
            // naming the 1-based page the user would recognize.
            guard !options.pages.isEmpty else { throw PDFEngineError.invalidPageRange("") }
            for case let index? in options.pages.map(\.sourcePageIndex)
            where !(0..<source.pageCount).contains(index) {
                throw PDFEngineError.invalidPageRange(String(index + 1))
            }

            var assembler = DocumentAssembler()
            var previousSize = Self.usLetter
            for (number, instruction) in options.pages.enumerated() {
                try reporter.update(Double(number) / Double(options.pages.count))
                let page: PDFPage
                if let index = instruction.sourcePageIndex {
                    let original = try source.requirePage(at: index, of: input.url)
                    page = assembler.append(copyOf: original)
                    page.rotation = PageGeometry.normalized(original.rotation + instruction.additionalRotation)
                } else {
                    page = assembler.appendBlank(size: previousSize,
                                                 rotation: instruction.additionalRotation)
                }
                // A following blank page matches this one as displayed, so it is created
                // upright at the displayed size rather than inheriting a rotation.
                previousSize = PageGeometry(box: page.bounds(for: .cropBox), rotation: page.rotation).readerSize
            }
            assembler.copyOutline(of: source)
            assembler.copyAttributes(of: source)

            let output = directory.reserve(OutputName.make(.organize, from: input.url))
            try assembler.write(to: output.url)
            return [output]
        }
    }
}
