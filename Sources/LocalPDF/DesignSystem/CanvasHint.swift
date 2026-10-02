import SwiftUI

/// A small floating glass caption at the bottom of a canvas ("Drag files to set the order").
struct CanvasHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .glassEffect(.regular, in: .capsule)
            .padding(.bottom, 14)
    }
}
