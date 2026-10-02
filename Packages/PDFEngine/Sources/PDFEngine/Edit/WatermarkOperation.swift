import Foundation
import PDFKit

/// Watermark: stamps text or an image over (or under) the page content.
public struct WatermarkOperation: PDFOperation {
    public static let tool: ToolID = .watermark

    public enum Content: Codable, Sendable, Hashable {
        case text(String, fontSize: Double, color: RGBAColor)
        /// A user-chosen image file; `scale` is relative to the page width (0...1).
        /// The image is shrunk further if it would otherwise be taller than the page.
        case image(URL, scale: Double)
    }

    public enum Layer: String, Codable, Sendable, Hashable, CaseIterable {
        case overContent, underContent
    }

    public struct Options: Codable, Sendable, Hashable {
        public var content: Content = .text("CONFIDENTIAL", fontSize: 48, color: .red)
        /// 0...1
        public var opacity: Double = 0.3
        /// Counter-clockwise degrees, as the reader sees the page.
        public var rotation: Double = 45
        public var position: StampPosition = .center
        /// Repeat the stamp in a grid across the page ("mosaic"); `position` is ignored.
        public var tiled: Bool = false
        public var layer: Layer = .overContent
        /// `PageRange` syntax, or `nil` for all pages.
        public var pages: PageSelection = nil
        public init() {}
    }

    public init() {}

    /// Distance from the page edge for non-centered positions.
    private static let margin: CGFloat = 24

    public func run(_ inputs: [InputFile], options: Options,
                    progress: @Sendable (Double) -> Void) async throws -> [OutputFile] {
        // Load an image watermark once; Quartz then embeds it once per output document.
        let image: OrientedImage? = switch options.content {
        case .image(let url, _): try OrientedImage(contentsOf: url)
        case .text: nil
        }

        return try Job.forEach(inputs, reportingTo: progress) { input, reporter, directory in
            let source = try DocumentIO.open(input)
            let selected = try PageSelectionResolver.indices(options.pages, pageCount: source.pageCount)

            let output = directory.reserve(OutputName.make(.watermark, from: input.url))
            try StampPipeline.stamp(
                source, sourceURL: input.url, pages: selected,
                layer: options.layer == .overContent ? .overContent : .underContent,
                to: output.url, scratch: directory.scratchURL(extension: "pdf"), progress: &reporter
            ) { context, pageSize, _ in
                Self.drawWatermark(options: options, image: image, in: context, pageSize: pageSize)
            }
            return [output]
        }
    }

    private static func drawWatermark(options: Options, image: OrientedImage?,
                                      in context: CGContext, pageSize: CGSize) {
        let drawUnrotated: (CGRect) -> Void
        let size: CGSize
        switch options.content {
        case .text(let string, let fontSize, let color):
            let text = StampText(string, fontSize: fontSize, color: color)
            size = text.size
            drawUnrotated = { text.draw(in: context, at: $0.origin) }
        case .image(_, let scale):
            guard let image else { return }
            let fraction = scale.isFinite ? min(max(scale, 0.01), 1) : 1
            let aspect = image.orientedSize.height / max(image.orientedSize.width, 1)
            // A tall image on a landscape page would overflow at its requested width.
            let maxHeight = max(pageSize.height - 2 * margin, 1)
            let width = min(pageSize.width * fraction, maxHeight / aspect)
            size = CGSize(width: width, height: width * aspect)
            drawUnrotated = { image.draw(in: context, rect: $0) }
        }
        guard size.width > 0, size.height > 0 else { return }

        let angle = (options.rotation.isFinite ? options.rotation : 0) * .pi / 180
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: angle)).size
        let centers = options.tiled
            ? tileCenters(for: rotatedSize, in: pageSize)
            : [centerOf(options.position.origin(for: rotatedSize, in: pageSize, margin: margin), rotatedSize)]

        context.saveGState()
        context.setAlpha(CGFloat(options.opacity.isFinite ? min(max(options.opacity, 0), 1) : 1))
        for center in centers {
            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: angle) // Positive is counter-clockwise in PDF's y-up space.
            drawUnrotated(CGRect(x: -size.width / 2, y: -size.height / 2,
                                 width: size.width, height: size.height))
            context.restoreGState()
        }
        context.restoreGState()
    }

    private static func centerOf(_ origin: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
    }

    /// A brick-offset grid of stamp centers, anchored on the page center, that covers the page.
    private static func tileCenters(for size: CGSize, in page: CGSize) -> [CGPoint] {
        let gap = max(36, 0.25 * max(size.width, size.height))
        let step = CGSize(width: size.width + gap, height: size.height + gap)
        let columns = Int((page.width / 2 / step.width).rounded(.up)) + 1
        let rows = Int((page.height / 2 / step.height).rounded(.up)) + 1
        var centers: [CGPoint] = []
        for row in -rows...rows {
            let offset = row.isMultiple(of: 2) ? 0 : step.width / 2
            for column in -columns...columns {
                centers.append(CGPoint(x: page.width / 2 + CGFloat(column) * step.width + offset,
                                       y: page.height / 2 + CGFloat(row) * step.height))
            }
        }
        return centers
    }
}
