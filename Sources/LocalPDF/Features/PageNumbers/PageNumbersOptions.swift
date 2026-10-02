import PDFEngine
import SwiftUI

/// Add Page Numbers' inspector section, with a live preview on the first page.
struct PageNumbersOptions: View {
    @Bindable var session: ToolSession

    var body: some View {
        if let file = session.file, let pageSize = file.firstPageSize {
            Section("Preview") {
                StampPreview(
                    page: file.thumbnail, pageSize: pageSize,
                    position: session.pageNumbers.position, margin: session.pageNumbers.margin
                ) { scale in
                    Text(sample(pageCount: file.pageCount))
                        .font(.system(size: max(session.pageNumbers.fontSize * scale, 1)))
                        .foregroundStyle(session.pageNumbers.color.color)
                        .fixedSize()
                }
            }
        }
        Section("Number") {
            LabeledContent("Position") {
                StampPositionPicker(selection: $session.pageNumbers.position)
            }
            Picker("Format", selection: $session.pageNumbers.format) {
                ForEach(Self.formats, id: \.self) { format in
                    Text(format.replacing("{n}", with: "1").replacing("{total}", with: "12")).tag(format)
                }
                if !Self.formats.contains(session.pageNumbers.format) {
                    Text("Custom").tag(session.pageNumbers.format)
                }
            }
            TextField("Template", text: $session.pageNumbers.format, prompt: Text("Page {n} of {total}"))
            Stepper(value: $session.pageNumbers.startNumber, in: 0...99_999) {
                LabeledContent("First number", value: "\(session.pageNumbers.startNumber)")
            }
        }
        Section("Text") {
            Stepper(value: $session.pageNumbers.fontSize, in: 6...72) {
                LabeledContent("Size", value: "\(Int(session.pageNumbers.fontSize)) pt")
            }
            ColorPicker("Color", selection: $session.pageNumbers.color.color, supportsOpacity: false)
            LabeledContent("Margin") {
                Slider(value: $session.pageNumbers.margin, in: 6...96) { Text("Margin") }
                    .labelsHidden()
                Text("\(Int(session.pageNumbers.margin)) pt")
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
            }
        }
        Section {
            PageSelectionField(selection: $session.pageNumbers.pages)
        } header: {
            Text("Apply To")
        } footer: {
            Text("Use {n} for the page number and {total} for the last number.")
        }
    }

    private func sample(pageCount: Int) -> String {
        let options = session.pageNumbers
        return options.format
            .replacing("{n}", with: "\(options.startNumber)")
            .replacing("{total}", with: "\(options.startNumber + max(pageCount, 1) - 1)")
    }

    private static let formats = ["{n}", "Page {n}", "{n} of {total}", "Page {n} of {total}", "- {n} -"]
}
