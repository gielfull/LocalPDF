import CoreGraphics

/// A page box as the reader sees it, with the page's `/Rotate` applied.
///
/// "Reader space" has its origin at the bottom-left of the page as displayed, y up, and
/// is `readerSize` big. `readerToPage` maps it into the page's own (unrotated) space, which
/// is where content, boxes and annotations live.
struct PageGeometry {
    /// The box in page space, e.g. the crop box.
    let box: CGRect
    /// Clockwise display rotation: 0, 90, 180 or 270.
    let rotation: Int

    init(box: CGRect, rotation: Int) {
        self.box = box.standardized
        self.rotation = Self.normalized(rotation)
    }

    var readerSize: CGSize {
        rotation % 180 == 0 ? box.size : CGSize(width: box.height, height: box.width)
    }

    var readerToPage: CGAffineTransform {
        let (x0, y0, w, h) = (box.minX, box.minY, box.width, box.height)
        switch rotation {
        case 90:
            // Displayed bottom-left is the page's bottom-right; reader x runs up the page.
            return CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: x0 + w, ty: y0)
        case 180:
            return CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: x0 + w, ty: y0 + h)
        case 270:
            return CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: x0, ty: y0 + h)
        default:
            return CGAffineTransform(translationX: x0, y: y0)
        }
    }

    /// Any angle in degrees to 0, 90, 180 or 270, snapping to the nearest quarter turn.
    static func normalized(_ degrees: Int) -> Int {
        let quarterTurns = Int((Double(degrees) / 90).rounded())
        return ((quarterTurns % 4) + 4) % 4 * 90
    }
}
