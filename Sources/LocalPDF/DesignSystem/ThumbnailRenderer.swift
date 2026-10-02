import CoreGraphics
import Foundation
import ImageIO

/// What to draw a thumbnail of: one page of a PDF, or an image file.
nonisolated struct ThumbnailSource: Hashable, Sendable {
    enum Kind: Hashable, Sendable { case pdfPage(Int), image }

    let url: URL
    let kind: Kind
    /// Open password for an encrypted PDF. Not part of the cache key.
    var password: String?

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.url == rhs.url && lhs.kind == rhs.kind }
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(kind)
    }
}

/// Renders thumbnails with CoreGraphics and ImageIO only, so the work runs off the main
/// actor and hands back a `CGImage` rather than a non-`Sendable` `NSImage`.
nonisolated enum ThumbnailRenderer {
    /// Renders `source` to fit within `maxPixels`, honoring the page's own `/Rotate`.
    @concurrent
    static func render(_ source: ThumbnailSource, maxPixels: CGSize) async -> CGImage? {
        let scoped = source.url.startAccessingSecurityScopedResource()
        defer { if scoped { source.url.stopAccessingSecurityScopedResource() } }

        switch source.kind {
        case .image:
            return renderImage(source.url, maxPixels: maxPixels)
        case .pdfPage(let index):
            return renderPage(source.url, index: index, password: source.password, maxPixels: maxPixels)
        }
    }

    private static func renderImage(_ url: URL, maxPixels: CGSize) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixels.width, maxPixels.height),
        ]
        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }

    private static func renderPage(_ url: URL, index: Int, password: String?, maxPixels: CGSize) -> CGImage? {
        guard let document = CGPDFDocument(url as CFURL) else { return nil }
        if document.isEncrypted, !document.isUnlocked {
            // Owner-password-only files open with the empty password.
            if !document.unlockWithPassword("") {
                guard let password, document.unlockWithPassword(password) else { return nil }
            }
        }
        guard let page = document.page(at: index + 1) else { return nil }

        let box = page.getBoxRect(.cropBox)
        let rotation = ((Int(page.rotationAngle) % 360) + 360) % 360
        let pageSize = rotation % 180 == 0 ? box.size : CGSize(width: box.height, height: box.width)
        guard pageSize.width > 0, pageSize.height > 0 else { return nil }

        let scale = min(maxPixels.width / pageSize.width, maxPixels.height / pageSize.height)
        let width = max(1, Int((pageSize.width * scale).rounded()))
        let height = max(1, Int((pageSize.height * scale).rounded()))
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.scaleBy(x: CGFloat(width) / pageSize.width, y: CGFloat(height) / pageSize.height)

        // Turn the page clockwise by its /Rotate so it reads the way a viewer shows it.
        switch rotation {
        case 90:
            context.translateBy(x: 0, y: pageSize.height)
            context.rotate(by: -.pi / 2)
        case 180:
            context.translateBy(x: pageSize.width, y: pageSize.height)
            context.rotate(by: .pi)
        case 270:
            context.translateBy(x: pageSize.width, y: 0)
            context.rotate(by: .pi / 2)
        default:
            break
        }
        context.translateBy(x: -box.minX, y: -box.minY)
        context.clip(to: box)
        context.drawPDFPage(page)
        return context.makeImage()
    }
}
