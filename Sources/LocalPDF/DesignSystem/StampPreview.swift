import PDFEngine
import SwiftUI

/// A first-page thumbnail with a stamp drawn over it in SwiftUI, to preview page numbers
/// and watermarks without running the engine. Sizes are in page points; `stamp` receives
/// the points-to-preview scale so it can size itself like the real result.
struct StampPreview<Stamp: View>: View {
    let page: ThumbnailSource
    /// The page's displayed size in points.
    let pageSize: CGSize
    let position: StampPosition
    /// Distance from the page edge, in points.
    var margin: CGFloat = 0
    /// Repeat the stamp across the page instead of placing it at `position`.
    var tiled = false
    @ViewBuilder let stamp: (_ scale: CGFloat) -> Stamp

    var body: some View {
        Color.clear
            .aspectRatio(pageSize, contentMode: .fit)
            .overlay { PageThumbnail(source: page, maxSize: CGSize(width: 260, height: 260)) }
            .overlay {
                GeometryReader { proxy in
                    let scale = proxy.size.width / max(pageSize.width, 1)
                    if tiled {
                        tiles(scale: scale, in: proxy.size)
                    } else {
                        stamp(scale)
                            .padding(margin * scale)
                            .frame(width: proxy.size.width, height: proxy.size.height, alignment: position.alignment)
                    }
                }
                .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: 260)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Preview of the first page")
    }

    private func tiles(scale: CGFloat, in size: CGSize) -> some View {
        let columns = 3
        let rows = 4
        return VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 0) {
                    ForEach(0..<columns, id: \.self) { _ in
                        stamp(scale)
                            .frame(width: size.width / CGFloat(columns), height: size.height / CGFloat(rows))
                    }
                }
            }
        }
    }
}
