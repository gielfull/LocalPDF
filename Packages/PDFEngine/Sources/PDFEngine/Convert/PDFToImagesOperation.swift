import CoreGraphics
import Foundation
import PDFKit
import UniformTypeIdentifiers

/// PDF to Images: renders every page, or extracts the embedded images as-is.
public struct PDFToImagesOperation: PDFOperation {
    public static let tool: ToolID = .pdfToImages

    public enum Mode: String, Codable, Sendable, Hashable, CaseIterable {
        /// One image per page.
        case renderPages
        /// The images embedded in the PDF, at their original resolution. JPEG images are
        /// written byte-for-byte when `format` is `.jpeg`; others are decoded best effort
        /// (soft masks dropped, exotic color spaces skipped). A PDF with no extractable
        /// image throws `.unsupportedInput`.
        case extractImages
    }

    public enum Format: String, Codable, Sendable, Hashable, CaseIterable {
        case jpeg, png, heic
    }

    public struct Options: Codable, Sendable, Hashable {
        public var mode: Mode = .renderPages
        public var format: Format = .jpeg
        /// Render resolution for `.renderPages` (72...600).
        public var dpi: Int = 150
        /// JPEG/HEIC quality, 0...1.
        public var quality: Double = 0.85
        public init() {}
    }

    public init() {}

    public func run(_ inputs: [InputFile], options: Options,
                    progress: @Sendable (Double) -> Void) async throws -> [OutputFile] {
        try Job.forEach(inputs, reportingTo: progress) { input, reporter, directory in
            let source = try DocumentIO.open(input)
            return switch options.mode {
            case .renderPages:
                try Self.renderPages(of: source, input: input, options: options,
                                     directory: &directory, progress: &reporter)
            case .extractImages:
                try Self.extractImages(of: source, input: input, options: options,
                                       directory: &directory, progress: &reporter)
            }
        }
    }

    /// Each page as the reader sees it (crop box, rotation, annotations) on white.
    private static func renderPages(
        of source: PDFDocument, input: InputFile, options: Options,
        directory: inout OutputDirectory, progress: inout ProgressReporter
    ) throws -> [OutputFile] {
        let scale = CGFloat(min(max(options.dpi, 72), 600)) / 72
        let digits = max(3, String(source.pageCount).count)
        var outputs: [OutputFile] = []

        for index in 0..<source.pageCount {
            try progress.update(Double(index) / Double(source.pageCount))
            let page = try source.requirePage(at: index, of: input.url)
            let size = PageGeometry(box: page.bounds(for: .cropBox), rotation: page.rotation).readerSize
            let width = Int((size.width * scale).rounded())
            let height = Int((size.height * scale).rounded())
            let output = directory.reserve(OutputName.make(
                .pdfToImages, from: input.url, detail: "page-\(padded(index + 1, digits))",
                extension: options.format.fileExtension))

            guard let canvas = ImageEncoding.whiteCanvas(width: width, height: height) else {
                throw PDFEngineError.writeFailed(output.url)
            }
            canvas.scaleBy(x: CGFloat(width) / size.width, y: CGFloat(height) / size.height)
            page.draw(with: .cropBox, to: canvas)
            guard let image = canvas.makeImage() else { throw PDFEngineError.writeFailed(output.url) }
            try ImageEncoding.write(image, to: output.url, type: options.format.type, quality: options.quality)
            outputs.append(output)
        }
        return outputs
    }

    /// Every distinct image XObject, in page order, at its stored resolution.
    private static func extractImages(
        of source: PDFDocument, input: InputFile, options: Options,
        directory: inout OutputDirectory, progress: inout ProgressReporter
    ) throws -> [OutputFile] {
        var seen = Set<CGPDFStreamRef>()
        var outputs: [OutputFile] = []

        for index in 0..<source.pageCount {
            try progress.update(Double(index) / Double(source.pageCount))
            guard let pdfPage = try source.requirePage(at: index, of: input.url).pageRef else { continue }
            for stream in PDFImageXObjects.images(on: pdfPage, seen: &seen) {
                guard let image = EmbeddedImage(stream: stream) else { continue }
                let name = OutputName.make(.pdfToImages, from: input.url, detail: "image-\(padded(outputs.count + 1, 3))",
                                           extension: options.format.fileExtension)
                if case .jpeg(let data) = image, options.format == .jpeg {
                    let output = directory.reserve(name)
                    do {
                        try data.write(to: output.url)
                    } catch {
                        throw PDFEngineError.writeFailed(output.url)
                    }
                    outputs.append(output)
                } else if let bitmap = image.cgImage {
                    let output = directory.reserve(name)
                    try ImageEncoding.write(bitmap, to: output.url, type: options.format.type,
                                            quality: options.quality)
                    outputs.append(output)
                }
            }
        }
        guard !outputs.isEmpty else { throw PDFEngineError.unsupportedInput(input.url) }
        return outputs
    }

    private static func padded(_ number: Int, _ digits: Int) -> String {
        let text = String(number)
        return String(repeating: "0", count: max(digits - text.count, 0)) + text
    }
}

private extension PDFToImagesOperation.Format {
    var type: UTType {
        switch self {
        case .jpeg: .jpeg
        case .png: .png
        case .heic: .heic
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .png: "png"
        case .heic: "heic"
        }
    }
}
