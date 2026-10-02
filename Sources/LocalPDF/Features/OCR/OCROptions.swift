import PDFEngine
import SwiftUI

/// OCR PDF's inspector section: the document languages, then how text is recognized.
struct OCROptions: View {
    @Bindable var session: ToolSession

    var body: some View {
        Section {
            LabeledContent("Language") {
                Menu(OCRLanguage.summary(of: session.ocr.languages)) {
                    Toggle("Automatic", isOn: automatic)
                    Divider()
                    ForEach(OCRLanguage.all) { language in
                        Toggle(language.name, isOn: isSelected(language))
                    }
                }
                .fixedSize()
            }
        } header: {
            Text("Document Language")
        } footer: {
            Text(session.ocr.languages.isEmpty
                 ? "LocalPDF detects the language of each page."
                 : "Choose every language the documents use.")
        }
        Section {
            Picker("Accuracy", selection: $session.ocr.accuracy) {
                Text("Accurate").tag(OCROperation.Accuracy.accurate)
                Text("Fast").tag(OCROperation.Accuracy.fast)
            }
            .pickerStyle(.segmented)
            Toggle("Skip pages that already have text", isOn: $session.ocr.skipPagesWithText)
        } header: {
            Text("Recognition")
        } footer: {
            Text(recognitionFooter)
        }
    }

    private var recognitionFooter: String {
        guard session.ocr.accuracy == .fast else {
            return "Pages look exactly the same; their text becomes searchable and selectable."
        }
        let unsupported = session.ocr.languages.filter { !OCRLanguage.fastTags.contains($0) }
        if !unsupported.isEmpty {
            let names = unsupported.map { OCRLanguage.summary(of: [$0]) }
            return "Fast doesn't read \(names.formatted(.list(type: .or))), so Accurate is used."
        }
        let fast = OCRLanguage.all.filter { OCRLanguage.fastTags.contains($0.id) }.map(\.name)
        return "Quicker, with more mistakes. Reads \(fast.formatted(.list(type: .and)))."
    }

    private var automatic: Binding<Bool> {
        Binding(
            get: { session.ocr.languages.isEmpty },
            set: { if $0 { session.ocr.languages = [] } }
        )
    }

    /// Selected languages keep the order they were picked in: the first is the most likely.
    private func isSelected(_ language: OCRLanguage) -> Binding<Bool> {
        Binding(
            get: { session.ocr.languages.contains(language.id) },
            set: { isOn in
                session.ocr.languages.removeAll { $0 == language.id }
                if isOn { session.ocr.languages.append(language.id) }
            }
        )
    }
}
