import CoreGraphics
import CoreText
import Foundation

/// Draws OCR results as invisible text (PDF text render mode 3), so a scanned page
/// becomes searchable and selectable while it looks exactly as before.
///
/// Each run is set in Helvetica (CoreText substitutes a font for scripts it lacks), sized
/// so its ascent plus descent fills the run's box height, then stretched horizontally to
/// the box width and rotated to the box's baseline. Selection highlights therefore land
/// on the scanned words.
enum InvisibleTextLayer {
    /// Draws `lines` into `context`, whose user space must be reader space (see
    /// `PageGeometry.readerToPage`).
    static func draw(_ lines: [RecognizedLine], in context: CGContext) {
        context.saveGState()
        context.setTextDrawingMode(.invisible)
        context.textMatrix = .identity
        for line in lines {
            for (index, run) in line.runs.enumerated() {
                // A real space between words keeps them apart in extracted text; it is not
                // counted when fitting the word to its box.
                let separator = index < line.runs.count - 1 ? " " : ""
                draw(run, separator: separator, in: context)
            }
        }
        context.restoreGState()
    }

    private static func draw(_ run: RecognizedLine.Run, separator: String, in context: CGContext) {
        let quad = run.quad
        let (width, height) = (quad.width, quad.height)
        guard !run.text.isEmpty, width.isFinite, height.isFinite, width > 0.5, height > 0.5 else { return }

        let unitFont = CTFontCreateWithName("Helvetica" as CFString, 1, nil)
        let unitHeight = CTFontGetAscent(unitFont) + CTFontGetDescent(unitFont)
        let font = CTFontCreateCopyWithAttributes(unitFont, height / unitHeight, nil, nil)
        let attributed = NSAttributedString(string: run.text + separator, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let fullWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        let glyphWidth = fullWidth - CTLineGetTrailingWhitespaceWidth(line)
        guard glyphWidth > 0 else { return }

        context.saveGState()
        context.translateBy(x: quad.bottomLeft.x, y: quad.bottomLeft.y)
        context.rotate(by: quad.angle)
        context.scaleBy(x: width / glyphWidth, y: 1)
        context.textPosition = CGPoint(x: 0, y: descent)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
