import PDFEngine
import SwiftUI

/// PDF to Images' inspector section: render pages, or pull out embedded images.
struct PDFToImagesOptions: View {
    @Bindable var session: ToolSession

    var body: some View {
        Section {
            Picker("Mode", selection: $session.pdfToImages.mode) {
                Text("Pages").tag(PDFToImagesOperation.Mode.renderPages)
                Text("Embedded Images").tag(PDFToImagesOperation.Mode.extractImages)
            }
            .pickerStyle(.tabs)
            .labelsHidden()

            Picker("Format", selection: $session.pdfToImages.format) {
                Text("JPEG").tag(PDFToImagesOperation.Format.jpeg)
                Text("PNG").tag(PDFToImagesOperation.Format.png)
                Text("HEIC").tag(PDFToImagesOperation.Format.heic)
            }
            .pickerStyle(.segmented)

            if session.pdfToImages.mode == .renderPages {
                Picker("Resolution", selection: $session.pdfToImages.dpi) {
                    Text("72 dpi (screen)").tag(72)
                    Text("150 dpi").tag(150)
                    Text("300 dpi (print)").tag(300)
                    Text("600 dpi").tag(600)
                }
            }
            if session.pdfToImages.format != .png {
                LabeledContent("Quality") {
                    Slider(value: $session.pdfToImages.quality, in: 0.3...1) {
                        Text("Quality")
                    }
                    .labelsHidden()
                    Text(session.pdfToImages.quality.formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }
        } header: {
            Text("Export")
        } footer: {
            Text(session.pdfToImages.mode == .renderPages
                 ? "One image per page."
                 : "The images inside the PDF, at their original resolution.")
        }
    }
}
