import SwiftUI

/// One saved output in the result sheet: thumbnail, name, size and the per-file actions.
struct ResultFileRow: View {
    let thumbnail: ThumbnailSource
    let name: String
    let byteCount: Int64
    let onQuickLook: () -> Void
    let onOpen: () -> Void
    let onReveal: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            PageThumbnail(source: thumbnail, maxSize: CGSize(width: 36, height: 44))
                .frame(width: 36, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(byteCount.formatted(.byteCount(style: .file)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            HStack(spacing: 2) {
                Button("Quick Look", systemImage: "eye", action: onQuickLook)
                Button("Open", systemImage: "arrow.up.forward.app", action: onOpen)
                Button("Show in Finder", systemImage: "folder", action: onReveal)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(byteCount.formatted(.byteCount(style: .file)))")
    }
}
