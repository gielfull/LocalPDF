import SwiftUI

/// Rotate PDF's inspector section.
struct RotateOptions: View {
    @Bindable var session: ToolSession

    var body: some View {
        Section("Rotation") {
            Picker("Direction", selection: $session.rotate.degrees) {
                Label("Left", systemImage: "rotate.left").tag(-90)
                Label("Right", systemImage: "rotate.right").tag(90)
                Text("180°").tag(180)
            }
            .pickerStyle(.segmented)
            PageSelectionField(selection: $session.rotate.pages)
        }
    }
}
