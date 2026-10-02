import PDFEngine
import SwiftUI

/// Add Watermark's inspector section: text or image (as tabs), then placement, with a
/// live preview on the first page.
struct WatermarkOptions: View {
    @Bindable var session: ToolSession

    @State private var isChoosingImage = false
    @State private var image: NSImage?

    var body: some View {
        if let file = session.file, let pageSize = file.firstPageSize {
            Section("Preview") {
                StampPreview(
                    page: file.thumbnail, pageSize: pageSize, position: session.watermark.position,
                    margin: 24, tiled: session.watermark.tiled
                ) { scale in
                    stamp(scale: scale, pageWidth: pageSize.width)
                        .opacity(session.watermark.opacity)
                        .rotationEffect(.degrees(-session.watermark.rotation))
                }
            }
        }
        Section {
            Picker("Content", selection: $session.watermarkKind) {
                ForEach(WatermarkKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.tabs)
            .labelsHidden()

            switch session.watermarkKind {
            case .text:
                TextField("Text", text: $session.watermarkText, prompt: Text("CONFIDENTIAL"))
                Stepper(value: $session.watermarkFontSize, in: 8...200, step: 2) {
                    LabeledContent("Size", value: "\(Int(session.watermarkFontSize)) pt")
                }
                ColorPicker("Color", selection: $session.watermarkColor.color, supportsOpacity: false)
            case .image:
                LabeledContent("Image") {
                    Button(session.watermarkImage?.lastPathComponent ?? "Choose…") { isChoosingImage = true }
                }
                labeledSlider("Size", value: $session.watermarkImageScale, in: 0.05...1, format: .percent.precision(.fractionLength(0)))
            }
        } header: {
            Text("Watermark")
        }
        Section("Placement") {
            labeledSlider("Opacity", value: $session.watermark.opacity, in: 0.05...1, format: .percent.precision(.fractionLength(0)))
            labeledSlider("Rotation", value: $session.watermark.rotation, in: -90...90, format: .number.precision(.fractionLength(0)), suffix: "°")
            Toggle("Repeat across the page", isOn: $session.watermark.tiled)
            LabeledContent("Position") {
                StampPositionPicker(selection: $session.watermark.position, isEnabled: !session.watermark.tiled)
            }
            Picker("Layer", selection: $session.watermark.layer) {
                Text("Over Content").tag(WatermarkOperation.Layer.overContent)
                Text("Under Content").tag(WatermarkOperation.Layer.underContent)
            }
            .pickerStyle(.segmented)
        }
        Section("Apply To") {
            PageSelectionField(selection: $session.watermark.pages)
        }
        .fileImporter(isPresented: $isChoosingImage, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            // Kept for the app's lifetime: the engine reads the image when the job runs.
            _ = url.startAccessingSecurityScopedResource()
            session.watermarkImage = url
        }
        .task(id: session.watermarkImage) {
            image = session.watermarkImage.flatMap { NSImage(contentsOf: $0) }
        }
    }

    @ViewBuilder
    private func stamp(scale: CGFloat, pageWidth: CGFloat) -> some View {
        switch session.watermarkKind {
        case .text:
            Text(session.watermarkText)
                .font(.system(size: max(session.watermarkFontSize * scale, 1), weight: .bold))
                .foregroundStyle(session.watermarkColor.color)
                .fixedSize()
        case .image:
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: pageWidth * session.watermarkImageScale * scale)
            }
        }
    }

    private func labeledSlider(
        _ title: String, value: Binding<Double>, in range: ClosedRange<Double>,
        format: some FormatStyle<Double, String>, suffix: String = ""
    ) -> some View {
        LabeledContent(title) {
            Slider(value: value, in: range) { Text(title) }
                .labelsHidden()
            Text(value.wrappedValue.formatted(format) + suffix)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }
}
