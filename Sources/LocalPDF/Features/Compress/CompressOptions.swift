import PDFEngine
import SwiftUI

/// Compress PDF's inspector section: iLovePDF's three levels.
struct CompressOptions: View {
    @Bindable var session: ToolSession

    var body: some View {
        Section("Compression Level") {
            Picker("Compression level", selection: $session.compress.level) {
                ForEach(CompressOperation.Level.allCases, id: \.self) { level in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(level.title)
                        Text(level.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(level)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            LabeledContent("Current size", value: session.files.reduce(Int64(0)) { $0 + $1.byteCount }.formatted(.byteCount(style: .file)))
        }
    }
}

extension CompressOperation.Level {
    var title: String {
        switch self {
        case .extreme: "Extreme"
        case .recommended: "Recommended"
        case .less: "Less"
        }
    }

    var detail: String {
        switch self {
        case .extreme: "Smallest file, lower image quality"
        case .recommended: "Good quality, good compression"
        case .less: "High quality, less compression"
        }
    }
}
