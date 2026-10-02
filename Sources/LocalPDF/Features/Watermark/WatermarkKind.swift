/// Watermark's content kind, flattened for the Text / Image picker; the engine's
/// `WatermarkOperation.Content` carries payloads, which a picker can't select between.
enum WatermarkKind: String, CaseIterable, Identifiable {
    case text, image

    var id: Self { self }

    var title: String {
        switch self {
        case .text: "Text"
        case .image: "Image"
        }
    }
}
