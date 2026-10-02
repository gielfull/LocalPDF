import SwiftUI

/// Repair PDF's inspector section: what Repair does, and how each file reads today.
struct RepairOptions: View {
    @Bindable var session: ToolSession

    var body: some View {
        Section {
            ForEach(session.files) { file in
                LabeledContent(file.name) {
                    Text(status(of: file))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Files")
        } footer: {
            Text("Rebuilds the file's structure (its index of objects and trailer) so PDF readers can open it again, and recovers every page that can be found. Your original files aren't changed.")
        }
    }

    private func status(of file: SourceFile) -> String {
        if file.needsPassword { return "Needs password" }
        return file.pageCount > 0 ? "Opens" : "Can't be opened"
    }
}
