import CoreGraphics

/// One line of text found by OCR, positioned in reader space: points, origin at the
/// bottom-left of the crop box as displayed, y up (see `PageGeometry`).
///
/// A line is drawn as one or more runs. When Vision can place every word, each word is a
/// run, so the invisible text sits on the scanned words even where the scan's font is
/// wider or narrower than ours; otherwise the whole line is a single run.
struct RecognizedLine: Sendable, Equatable {
    /// Text and the quadrilateral it covers on the page.
    struct Run: Sendable, Equatable {
        let text: String
        let quad: Quad
    }

    /// Corners of a (possibly skewed) box, as Vision reports them, in reader space.
    struct Quad: Sendable, Equatable {
        let bottomLeft: CGPoint
        let bottomRight: CGPoint
        let topRight: CGPoint
        let topLeft: CGPoint

        /// Length of the baseline, bottom-left to bottom-right.
        var width: CGFloat { distance(bottomLeft, bottomRight) }

        /// Mean of the left and right edges.
        var height: CGFloat { (distance(bottomLeft, topLeft) + distance(bottomRight, topRight)) / 2 }

        /// Baseline angle in radians, counter-clockwise from the x axis.
        var angle: CGFloat { atan2(bottomRight.y - bottomLeft.y, bottomRight.x - bottomLeft.x) }

        private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            hypot(b.x - a.x, b.y - a.y)
        }
    }

    /// The line's full transcript.
    let text: String
    /// What gets drawn, in reading order; joined by single spaces they spell `text`'s words.
    let runs: [Run]
}
