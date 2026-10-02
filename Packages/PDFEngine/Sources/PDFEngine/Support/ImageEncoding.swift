import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Encodes `CGImage`s with ImageIO.
enum ImageEncoding {
    /// Writes `image` to `url` as `type`. `quality` (0...1) applies to lossy formats.
    static func write(_ image: CGImage, to url: URL, type: UTType, quality: Double) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, type.identifier as CFString, 1, nil
        ) else {
            throw PDFEngineError.writeFailed(url)
        }
        CGImageDestinationAddImage(destination, image, properties(quality: quality))
        guard CGImageDestinationFinalize(destination) else {
            throw PDFEngineError.writeFailed(url)
        }
    }

    /// `image` encoded in memory as `type`, or `nil` if ImageIO can't encode it.
    static func data(_ image: CGImage, type: UTType, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, type.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, properties(quality: quality))
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// An opaque white sRGB bitmap context of `width` × `height` pixels, for rendering pages.
    static func whiteCanvas(width: Int, height: Int) -> CGContext? {
        guard width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else { return nil }
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        return context
    }

    private static func properties(quality: Double) -> CFDictionary {
        [kCGImageDestinationLossyCompressionQuality: min(max(quality, 0), 1)] as CFDictionary
    }
}
