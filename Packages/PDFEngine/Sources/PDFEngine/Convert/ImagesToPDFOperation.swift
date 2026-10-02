import CoreGraphics
import Foundation

/// Images to PDF: JPEG, PNG, HEIC, TIFF, WebP, GIF (first frame), RAW → PDF.
public struct ImagesToPDFOperation: PDFOperation {
    public static let tool: ToolID = .imagesToPDF

    public enum PageSize: String, Codable, Sendable, Hashable, CaseIterable {
        /// Page is exactly the image size (at 72 dpi-equivalent points), plus the margin
        /// on every side; `orientation` doesn't apply.
        case fitImage, a4, usLetter
    }

    public enum Orientation: String, Codable, Sendable, Hashable, CaseIterable {
        /// Landscape for landscape images, portrait otherwise.
        case automatic, portrait, landscape
    }

    public enum Margin: String, Codable, Sendable, Hashable, CaseIterable {
        case none, small, large
    }

    public struct Options: Codable, Sendable, Hashable {
        public var pageSize: PageSize = .a4
        public var orientation: Orientation = .automatic
        public var margin: Margin = .none
        /// One PDF with every image (in input order) instead of one PDF per image.
        public var mergeIntoOne: Bool = true
        public init() {}
    }

    public init() {}

    public func run(_ inputs: [InputFile], options: Options,
                    progress: @Sendable (Double) -> Void) async throws -> [OutputFile] {
        guard !inputs.isEmpty else { throw PDFEngineError.unsupportedInput(DocumentIO.noInputURL) }
        return try Job.run(reportingTo: progress) { reporter, directory in
            if options.mergeIntoOne {
                // Several images merged into one PDF are named after the first, like Merge.
                let output = directory.reserve(OutputName.make(.imagesToPDF, from: inputs[0].url))
                try Self.write(inputs, to: output.url, options: options, progress: &reporter)
                return [output]
            }
            var outputs: [OutputFile] = []
            for (index, input) in inputs.enumerated() {
                try reporter.beginItem(index, of: inputs.count)
                let output = directory.reserve(OutputName.make(.imagesToPDF, from: input.url))
                try Self.write([input], to: output.url, options: options, progress: &reporter)
                outputs.append(output)
            }
            return outputs
        }
    }

    /// One page per image, in order. Images are drawn as ImageIO decoded them, so JPEGs
    /// are embedded with their original bytes rather than re-compressed.
    private static func write(_ inputs: [InputFile], to url: URL, options: Options,
                              progress: inout ProgressReporter) throws {
        var defaultBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &defaultBox, nil) else {
            throw PDFEngineError.writeFailed(url)
        }
        for (index, input) in inputs.enumerated() {
            try progress.update(Double(index) / Double(inputs.count))
            let image = try OrientedImage(contentsOf: input.url)
            guard image.orientedSize.width > 0, image.orientedSize.height > 0 else {
                throw PDFEngineError.unsupportedInput(input.url)
            }
            let (page, imageRect) = layout(for: image.orientedSize, options: options)
            context.beginPDFPage(page.pdfPageInfo)
            image.draw(in: context, rect: imageRect)
            context.endPDFPage()
        }
        context.closePDF()
    }

    /// The page rect and where the image goes on it: aspect-fit inside the margins, centered.
    private static func layout(for imageSize: CGSize, options: Options) -> (page: CGRect, image: CGRect) {
        let margin: CGFloat = switch options.margin {
        case .none: 0
        case .small: 20
        case .large: 40
        }
        let paper: CGSize
        switch options.pageSize {
        case .fitImage:
            let page = CGRect(x: 0, y: 0, width: imageSize.width + 2 * margin,
                              height: imageSize.height + 2 * margin)
            return (page, page.insetBy(dx: margin, dy: margin))
        case .a4:
            paper = CGSize(width: 595.28, height: 841.89)
        case .usLetter:
            paper = CGSize(width: 612, height: 792)
        }

        let landscape = switch options.orientation {
        case .automatic: imageSize.width > imageSize.height
        case .portrait: false
        case .landscape: true
        }
        let long = max(paper.width, paper.height)
        let short = min(paper.width, paper.height)
        let page = CGRect(x: 0, y: 0, width: landscape ? long : short, height: landscape ? short : long)

        let available = page.insetBy(dx: margin, dy: margin)
        let scale = min(available.width / imageSize.width, available.height / imageSize.height)
        let drawn = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let imageRect = CGRect(x: available.midX - drawn.width / 2, y: available.midY - drawn.height / 2,
                               width: drawn.width, height: drawn.height)
        return (page, imageRect)
    }
}
