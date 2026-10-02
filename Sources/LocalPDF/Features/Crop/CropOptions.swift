import SwiftUI

/// Crop PDF's inspector section: margins to trim, in points.
struct CropOptions: View {
    @Bindable var session: ToolSession

    var body: some View {
        Section {
            margin("Top", $session.crop.top)
            margin("Bottom", $session.crop.bottom)
            margin("Left", $session.crop.left)
            margin("Right", $session.crop.right)
        } header: {
            Text("Trim Margins")
        } footer: {
            Text("In points (72 per inch), as the page appears on screen.")
        }
        Section("Apply To") {
            PageSelectionField(selection: $session.crop.pages)
        }
    }

    private func margin(_ title: String, _ value: Binding<Double>) -> some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField(title, value: value, format: .number.precision(.fractionLength(0...1)))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                Stepper(title, value: value, in: 0...2000, step: 6)
                    .labelsHidden()
            }
        }
    }
}
