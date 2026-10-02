import SwiftUI

/// An asynchronously rendered page or image thumbnail on a paper-like card.
/// Fits inside its frame; shows a placeholder while the render runs off the main actor.
struct PageThumbnail: View {
    let source: ThumbnailSource
    /// The largest size, in points, the thumbnail is shown at; renders at display scale.
    var maxSize = CGSize(width: 160, height: 200)

    @Environment(\.displayScale) private var displayScale
    @State private var image: NSImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .background(.white)
                    .clipShape(.rect(cornerRadius: 3))
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.background.secondary)
                    .aspectRatio(8.5 / 11, contentMode: .fit)
                    .overlay {
                        if didFail {
                            Image(systemName: "doc")
                                .font(.title)
                                .foregroundStyle(.tertiary)
                        } else {
                            ProgressView().controlSize(.small)
                        }
                    }
            }
        }
        // The password is in the task id (but not the cache key) so unlocking re-renders.
        .task(id: [source.url.absoluteString, "\(source.kind)", source.password ?? ""]) {
            let pixels = CGSize(width: maxSize.width * displayScale, height: maxSize.height * displayScale)
            if let cached = ThumbnailCache.shared.cachedImage(for: source, maxPixels: pixels) {
                image = cached
                return
            }
            image = await ThumbnailCache.shared.image(for: source, maxPixels: pixels)
            didFail = image == nil
        }
    }
}
