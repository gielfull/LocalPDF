import AppKit
import PDFEngine
import SwiftUI

/// How a `ToolCategory` looks in the app: its display title and tint.
///
/// The tints echo iLovePDF's color coding. They are system colors where
/// one fits, so Dark Mode and Increase Contrast adjust them for free; Security's navy
/// has no system equivalent and carries its own light, dark and high-contrast values.
struct CategoryStyle {
    let title: String
    let tint: Color

    static func of(_ category: ToolCategory) -> CategoryStyle {
        switch category {
        case .organize: CategoryStyle(title: "Organize", tint: .red)
        case .optimize: CategoryStyle(title: "Optimize", tint: .green)
        case .convertToPDF: CategoryStyle(title: "Convert to PDF", tint: .blue)
        case .convertFromPDF: CategoryStyle(title: "Convert from PDF", tint: .orange)
        case .edit: CategoryStyle(title: "Edit", tint: .purple)
        case .security: CategoryStyle(title: "Security", tint: navy)
        case .intelligence: CategoryStyle(title: "Intelligence", tint: .teal)
        }
    }

    /// Navy that stays legible on dark backgrounds and gets darker under Increase Contrast.
    private static let navy = Color(nsColor: NSColor(name: "LocalPDF.navy") { appearance in
        switch appearance.bestMatch(from: [
            .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
        ]) {
        case .darkAqua: NSColor(srgbRed: 0.45, green: 0.55, blue: 0.95, alpha: 1)
        case .accessibilityHighContrastDarkAqua: NSColor(srgbRed: 0.62, green: 0.70, blue: 1, alpha: 1)
        case .accessibilityHighContrastAqua: NSColor(srgbRed: 0.08, green: 0.13, blue: 0.40, alpha: 1)
        default: NSColor(srgbRed: 0.17, green: 0.25, blue: 0.62, alpha: 1)
        }
    })
}

extension ToolCategory {
    var style: CategoryStyle { CategoryStyle.of(self) }
}

extension ToolDescriptor {
    /// The tint of the tool's category.
    var tint: Color { category.style.tint }
}
