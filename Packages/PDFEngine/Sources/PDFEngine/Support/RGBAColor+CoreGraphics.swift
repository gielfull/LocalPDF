import CoreGraphics

extension RGBAColor {
    /// The color in sRGB, components clamped to `0...1`.
    var cgColor: CGColor {
        func clamp(_ value: Double) -> CGFloat { CGFloat(min(max(value, 0), 1)) }
        return CGColor(srgbRed: clamp(red), green: clamp(green), blue: clamp(blue), alpha: clamp(alpha))
    }
}
