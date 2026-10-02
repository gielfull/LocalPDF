import SwiftUI

/// Remove Pages' inspector section.
struct RemovePagesOptions: View {
    @Bindable var session: ToolSession

    var body: some View {
        Section {
            TextField("Pages to remove", text: $session.rangeText, prompt: Text("2, 5-7"))
            LabeledContent("Result", value: resultText)
        } header: {
            Text("Pages")
        } footer: {
            Text("Click pages on the left, or type page numbers and ranges.")
        }
    }

    private var resultText: String {
        guard let file = session.file else { return "—" }
        let removed = PageRangeSync.pages(in: session.rangeText, pageCount: file.pageCount).count
        return "Keeps \(file.pageCount - removed) of \(file.pageCount) pages"
    }
}
