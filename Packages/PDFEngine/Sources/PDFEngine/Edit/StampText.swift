import CoreGraphics
import CoreText
import Foundation

/// One line of stamp text, laid out with CoreText in the system font.
struct StampText {
    private let line: CTLine
    let size: CGSize
    private let descent: CGFloat

    init(_ string: String, fontSize: Double, color: RGBAColor) {
        let pointSize = CGFloat(max(fontSize, 1))
        let font = CTFontCreateUIFontForLanguage(.system, pointSize, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, pointSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]
        line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        self.size = CGSize(width: width, height: ascent + descent)
        self.descent = descent
    }

    /// Draws the line with the bottom-left of its typographic box at `origin`.
    func draw(in context: CGContext, at origin: CGPoint) {
        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: origin.x, y: origin.y + descent)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
