import CoreGraphics
import Foundation
import ImageIO

/// The first frame of an image file, plus its EXIF orientation.
///
/// Drawing applies the orientation with a transform instead of decoding a rotated copy,
/// so Quartz can embed a JPEG's original bytes in a PDF (DCTDecode passthrough) rather
/// than re-compressing pixels.
struct OrientedImage {
    let image: CGImage
    /// EXIF orientation, 1...8.
    let orientation: Int

    /// - Throws: `.unsupportedInput` when ImageIO can't read `url` as an image.
    init(contentsOf url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw PDFEngineError.unsupportedInput(url)
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        self.image = image
        self.orientation = (1...8).contains(orientation) ? orientation : 1
    }

    /// Orientations 5...8 turn the image a quarter, swapping width and height.
    private var isQuarterTurned: Bool { orientation >= 5 }

    /// Pixel size as displayed, orientation applied.
    var orientedSize: CGSize {
        let size = CGSize(width: image.width, height: image.height)
        return isQuarterTurned ? CGSize(width: size.height, height: size.width) : size
    }

    /// Draws the image upright, filling `rect` (which should have `orientedSize`'s aspect).
    func draw(in context: CGContext, rect: CGRect) {
        let (width, height) = (rect.width, rect.height)
        var transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
        // EXIF orientation → the transform that shows the stored pixels upright, in a y-up
        // context. 2/4/5/7 are the mirrored variants of 1/3/8/6.
        switch orientation {
        case 3, 4:
            transform = transform.translatedBy(x: width, y: height).rotated(by: .pi)
        case 5, 8:
            transform = transform.translatedBy(x: width, y: 0).rotated(by: .pi / 2)
        case 6, 7:
            transform = transform.translatedBy(x: 0, y: height).rotated(by: -.pi / 2)
        default:
            break
        }
        switch orientation {
        case 2, 4:
            transform = transform.translatedBy(x: width, y: 0).scaledBy(x: -1, y: 1)
        case 5, 7:
            transform = transform.translatedBy(x: height, y: 0).scaledBy(x: -1, y: 1)
        default:
            break
        }
        context.saveGState()
        context.concatenate(transform)
        let drawSize = isQuarterTurned ? CGSize(width: height, height: width) : rect.size
        context.draw(image, in: CGRect(origin: .zero, size: drawSize))
        context.restoreGState()
    }
}
