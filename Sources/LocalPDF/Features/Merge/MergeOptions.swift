import SwiftUI

/// Merge PDF's inspector section.
struct MergeOptions: View {
    @Bindable var session: ToolSession

    var body: some View {
        Section {
            Toggle("Add a bookmark for each file", isOn: $session.merge.addBookmarks)
            LabeledContent("Pages", value: "\(session.files.reduce(0) { $0 + $1.pageCount })")
        } header: {
            Text("Options")
        } footer: {
            Text("Files are combined in the order shown. Drag the cards to change it.")
        }
    }
}
