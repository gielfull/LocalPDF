import PDFEngine
import SwiftUI

/// Images to PDF's inspector section.
struct ImagesToPDFOptions: View {
    @Bindable var session: ToolSession

    var body: some View {
        Section("Page") {
            Picker("Page size", selection: $session.imagesToPDF.pageSize) {
                Text("Fit to Image").tag(ImagesToPDFOperation.PageSize.fitImage)
                Text("A4").tag(ImagesToPDFOperation.PageSize.a4)
                Text("US Letter").tag(ImagesToPDFOperation.PageSize.usLetter)
            }
            Picker("Orientation", selection: $session.imagesToPDF.orientation) {
                Text("Automatic").tag(ImagesToPDFOperation.Orientation.automatic)
                Text("Portrait").tag(ImagesToPDFOperation.Orientation.portrait)
                Text("Landscape").tag(ImagesToPDFOperation.Orientation.landscape)
            }
            .disabled(session.imagesToPDF.pageSize == .fitImage)
            Picker("Margin", selection: $session.imagesToPDF.margin) {
                Text("None").tag(ImagesToPDFOperation.Margin.none)
                Text("Small").tag(ImagesToPDFOperation.Margin.small)
                Text("Large").tag(ImagesToPDFOperation.Margin.large)
            }
            .pickerStyle(.segmented)
        }
        Section {
            Toggle("Combine into one PDF", isOn: $session.imagesToPDF.mergeIntoOne)
        } footer: {
            Text(session.imagesToPDF.mergeIntoOne
                 ? "One PDF with a page per image, in the order shown."
                 : "A separate PDF for each image.")
        }
    }
}
