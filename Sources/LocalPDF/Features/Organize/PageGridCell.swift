import SwiftUI

/// One page in a page grid (Organize, Split, Remove, Extract): thumbnail, number,
/// selection ring and an optional badge. Blank pages pass a nil thumbnail.
struct PageGridCell: View {
    /// What a selected page means in this tool, which decides how selection looks.
    enum Emphasis {
        case select
        /// Remove Pages: selected pages are crossed out.
        case remove
    }

    let thumbnail: ThumbnailSource?
    let label: String
    /// VoiceOver label, e.g. "Page 3 of report.pdf, rotated 90°".
    let accessibilityText: String
    var rotation = 0
    var isSelected = false
    var emphasis = Emphasis.select
    /// Dims pages that aren't part of the result.
    var isDimmed = false
    var badge: Badge?
    /// Shows a magnifier button on hover that opens the page preview.
    var onPreview: (() -> Void)?
    /// Reports hover, so the grid knows which page Space should preview.
    var onHoverChange: ((Bool) -> Void)?

    struct Badge {
        let text: String
        let tint: Color
    }

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                page
                    .rotationEffect(.degrees(Double(rotation)))
                    .animation(.snappy, value: rotation)
                    .opacity(isDimmed ? 0.4 : 1)
                if isSelected, emphasis == .remove {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.red, in: .circle)
                }
            }
            .frame(width: Self.side, height: Self.side)
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AnyShapeStyle(ringColor.opacity(0.14)) : AnyShapeStyle(.fill.quaternary.opacity(isHovering ? 1 : 0)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(ringColor, lineWidth: isSelected ? 2.5 : 0)
            }
            .overlay(alignment: .topTrailing) {
                if isHovering, let onPreview {
                    Button("Preview Page", systemImage: "magnifyingglass", action: onPreview)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.small)
                        .help("Preview Page (Space)")
                        .padding(5)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.18), value: isHovering)
            .overlay(alignment: .topLeading) {
                if let badge {
                    Text(badge.text)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badge.tint, in: .capsule)
                        .padding(5)
                }
            }

            Text(label)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .monospacedDigit()
        }
        .contentShape(.rect)
        .onHover { hovering in
            isHovering = hovering
            onHoverChange?(hovering)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private var page: some View {
        if let thumbnail {
            PageThumbnail(source: thumbnail, maxSize: CGSize(width: Self.side, height: Self.side))
        } else {
            Rectangle()
                .fill(.white)
                .aspectRatio(8.5 / 11, contentMode: .fit)
                .overlay {
                    Text("Blank")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
        }
    }

    private var ringColor: Color { emphasis == .remove ? .red : .accentColor }

    static let side: CGFloat = 132
    static let columns = [GridItem(.adaptive(minimum: side + 24, maximum: side + 48), spacing: 12)]
}
