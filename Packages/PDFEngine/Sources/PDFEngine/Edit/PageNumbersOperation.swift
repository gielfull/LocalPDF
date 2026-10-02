import Foundation
import PDFKit

/// Add Page Numbers: stamps a number on each selected page.
public struct PageNumbersOperation: PDFOperation {
    public static let tool: ToolID = .pageNumbers

    public struct Options: Codable, Sendable, Hashable {
        public var position: StampPosition = .bottomCenter
        /// Template with `{n}` (this page's number) and `{total}` (last number),
        /// e.g. "{n}", "Page {n}", "{n} of {total}".
        public var format: String = "{n}"
        /// Number printed on the first numbered page.
        public var startNumber: Int = 1
        /// `PageRange` syntax for which pages get a number, or `nil` for all.
        public var pages: PageSelection = nil
        public var fontSize: Double = 11
        public var color: RGBAColor = .black
        /// Distance from the page edge, in points.
        public var margin: Double = 28
        public init() {}
    }

    public init() {}

    public func run(_ inputs: [InputFile], options: Options,
                    progress: @Sendable (Double) -> Void) async throws -> [OutputFile] {
        try Job.forEach(inputs, reportingTo: progress) { input, reporter, directory in
            let source = try DocumentIO.open(input)
            let selected = try PageSelectionResolver.indices(options.pages, pageCount: source.pageCount)

            // Numbered pages count up from `startNumber` in page order, so "3-" puts the
            // start number on page 3.
            var numbers: [Int: Int] = [:]
            for (rank, index) in selected.sorted().enumerated() {
                numbers[index] = options.startNumber + rank
            }
            let total = options.startNumber + selected.count - 1
            let margin = CGFloat(options.margin.isFinite ? max(options.margin, 0) : 0)

            let output = directory.reserve(OutputName.make(.pageNumbers, from: input.url))
            try StampPipeline.stamp(
                source, sourceURL: input.url, pages: selected, layer: .overContent,
                to: output.url, scratch: directory.scratchURL(extension: "pdf"), progress: &reporter
            ) { context, size, index in
                guard let number = numbers[index] else { return }
                let label = options.format
                    .replacingOccurrences(of: "{n}", with: String(number))
                    .replacingOccurrences(of: "{total}", with: String(total))
                let text = StampText(label, fontSize: options.fontSize, color: options.color)
                text.draw(in: context, at: options.position.origin(for: text.size, in: size, margin: margin))
            }
            return [output]
        }
    }
}
