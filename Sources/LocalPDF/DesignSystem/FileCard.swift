import SwiftUI

/// One input file on a tool's canvas: first-page thumbnail, name, details and a remove
/// button that appears on hover (and is always available to VoiceOver).
struct FileCard: View {
    let thumbnail: ThumbnailSource
    let name: String
    /// e.g. "12 pages · 2.4 MB".
    let detail: String
    var isLocked = false
    /// Position in a reorderable list, shown as a badge ("1", "2"…); nil hides it.
    var position: Int?
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 10) {
            PageThumbnail(source: thumbnail, maxSize: CGSize(width: 140, height: 170))
                .frame(width: 140, height: 170)
                .overlay(alignment: .bottomTrailing) {
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption.weight(.semibold))
                            .padding(6)
                            .glassEffect(.regular, in: .circle)
                            .padding(4)
                    }
                }
            VStack(spacing: 2) {
                Text(name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(12)
        .frame(width: 176)
        .background(.fill.quaternary.opacity(isHovering ? 1 : 0), in: .rect(cornerRadius: 14))
        .overlay(alignment: .topLeading) {
            if let position {
                Text("\(position)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .frame(minWidth: 22, minHeight: 22)
                    .glassEffect(.regular.tint(.accentColor.opacity(0.35)), in: .capsule)
                    .padding(6)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button("Remove \(name)", systemImage: "xmark", action: onRemove)
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .padding(4)
                .opacity(isHovering ? 1 : 0)
                .help("Remove")
        }
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.15), value: isHovering)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(position.map { "\($0). \(name)" } ?? name)
        .accessibilityValue(isLocked ? "\(detail), password protected" : detail)
        .accessibilityAction(named: "Remove", onRemove)
    }
}
