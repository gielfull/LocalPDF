import SwiftUI

/// The file a one-file tool is working on, floating above its page canvas, with the way
/// out when it's the wrong one: Replace… picks another file, × goes back to the empty
/// drop state. Removing a file whose pages were rearranged in Organize asks first.
struct LoadedFileBar: View {
    let session: ToolSession
    let onReplace: () -> Void

    @State private var confirmsRemoval = false

    var body: some View {
        if let file = session.file {
            HStack(spacing: 10) {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(file.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(file.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .frame(maxWidth: 320, alignment: .leading)

                Divider().frame(height: 22)

                Button("Replace…", action: onReplace)
                    .buttonStyle(.borderless)
                    .help("Choose a different file")
                Button("Remove File", systemImage: "xmark.circle.fill", action: remove)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Remove \u{201C}\(file.name)\u{201D}")
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .padding(.vertical, 7)
            .glassEffect(.regular, in: .capsule)
            .padding(.top, 10)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Current file, \(file.name)")
            .confirmationDialog(
                "Remove \u{201C}\(file.name)\u{201D}?", isPresented: $confirmsRemoval
            ) {
                Button("Remove and Discard Changes", role: .destructive) { removeNow() }
            } message: {
                Text("Your changes to the page order and rotation will be lost.")
            }
        }
    }

    private func remove() {
        if session.tool == .organize, session.pagePlan.isModified {
            confirmsRemoval = true
        } else {
            removeNow()
        }
    }

    private func removeNow() {
        withAnimation(.snappy) { session.removeAll() }
    }
}
