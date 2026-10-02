import SwiftUI

/// Split PDF's inspector section: the mode as tabs, then that mode's setting.
struct SplitOptions: View {
    @Bindable var session: ToolSession

    var body: some View {
        Section {
            Picker("Split by", selection: $session.splitMode) {
                ForEach(SplitModeKind.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.tabs)
            .labelsHidden()

            switch session.splitMode {
            case .ranges:
                TextField("Ranges", text: $session.rangeText, prompt: Text("1-3, 4-6, 7-"))
            case .everyN:
                Stepper(value: $session.splitEvery, in: 1...max(1, pageCount)) {
                    LabeledContent("Pages per file", value: "\(session.splitEvery)")
                }
            case .eachPage:
                EmptyView()
            }
            LabeledContent("Result", value: resultText)
        } header: {
            Text("Split")
        } footer: {
            Text(footer)
        }
    }

    private var pageCount: Int { session.file?.pageCount ?? 0 }

    private var resultText: String {
        let files = Set(session.splitGroups.values).count
        return files == 0 ? "—" : "\(files) PDF \(files == 1 ? "file" : "files")"
    }

    private var footer: String {
        switch session.splitMode {
        case .ranges: "Each comma-separated range becomes its own PDF. Click pages to add them."
        case .everyN: "Cuts the document into files of this many pages; the last may be shorter."
        case .eachPage: "Every page becomes its own PDF."
        }
    }
}
