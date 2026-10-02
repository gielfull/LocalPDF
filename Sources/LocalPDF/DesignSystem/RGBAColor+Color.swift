import AppKit
import PDFEngine
import SwiftUI

extension RGBAColor {
    /// The color for drawing previews in SwiftUI.
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    /// Converts any SwiftUI color (including catalog and dynamic ones) to sRGB data.
    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(red: ns.redComponent, green: ns.greenComponent, blue: ns.blueComponent, alpha: ns.alphaComponent)
    }
}

extension Binding where Value == RGBAColor {
    /// Bridges an options color to a `ColorPicker`.
    var color: Binding<Color> {
        Binding<Color>(
            get: { wrappedValue.color },
            set: { wrappedValue = RGBAColor($0) }
        )
    }
}
