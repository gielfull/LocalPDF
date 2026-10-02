import SwiftUI

/// Extract Pages' inspector section.
struct ExtractPagesOptions: View {
    @Bindable var session: ToolSession

    var body: some View {
        Section {
            TextField("Pages to extract", text: $session.rangeText, prompt: Text("1, 4-6"))
            Toggle("Save each page as a separate PDF", isOn: $session.extract.separateFiles)
            LabeledContent("Result", value: resultText)
        } header: {
            Text("Pages")
        } footer: {
            Text("Pages are extracted in the order you type them.")
        }
    }

    private var resultText: String {
        guard let file = session.file else { return "—" }
        let count = PageRangeSync.pages(in: session.rangeText, pageCount: file.pageCount).count
        guard count > 0 else { return "—" }
        if session.extract.separateFiles { return "\(count) PDF \(count == 1 ? "file" : "files")" }
        return "1 PDF, \(count) \(count == 1 ? "page" : "pages")"
    }
}
