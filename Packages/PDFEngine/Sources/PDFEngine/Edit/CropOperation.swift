import Foundation
import PDFKit

/// Crop PDF: shrinks the crop box of the selected pages.
public struct CropOperation: PDFOperation {
    public static let tool: ToolID = .crop

    public struct Options: Codable, Sendable, Hashable {
        /// Insets from the current crop box, in points, as the reader sees the page
        /// (i.e. already accounting for page rotation). Negative values count as 0; insets
        /// that leave less than 1 pt of a page throw `.invalidPageRange` naming that page.
        public var top: Double = 0
        public var left: Double = 0
        public var bottom: Double = 0
        public var right: Double = 0
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
                let page = assembler.append(copyOf: try source.requirePage(at: index, of: input.url))
                guard selected.contains(index) else { continue }
                guard let cropBox = Self.croppedBox(of: page, options: options) else {
                    throw PDFEngineError.invalidPageRange(String(index + 1))
                }
                page.setBounds(cropBox, for: .cropBox)
            }
            assembler.copyOutline(of: source)
            assembler.copyAttributes(of: source)

            let output = directory.reserve(OutputName.make(.crop, from: input.url))
            try assembler.write(to: output.url)
            return [output]
        }
    }

    /// The new crop box in page space, or `nil` if the insets leave nothing of the page.
    /// The media box is untouched, so the crop stays reversible.
    private static func croppedBox(of page: PDFPage, options: Options) -> CGRect? {
        func inset(_ value: Double) -> CGFloat { value.isFinite ? CGFloat(max(value, 0)) : 0 }
        let geometry = PageGeometry(box: page.bounds(for: .cropBox), rotation: page.rotation)
        let reader = geometry.readerSize
        let (top, left, bottom, right) = (inset(options.top), inset(options.left),
                                          inset(options.bottom), inset(options.right))
        let width = reader.width - left - right
        let height = reader.height - top - bottom
        guard width >= 1, height >= 1 else { return nil }
        let kept = CGRect(x: left, y: bottom, width: width, height: height)
        // Quarter-turn transforms map rectangles exactly onto rectangles.
        return kept.applying(geometry.readerToPage)
    }
}
