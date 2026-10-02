import AppKit

/// In-memory thumbnail cache keyed by URL + page + pixel size. Rendering happens off the
/// main actor in `ThumbnailRenderer`; concurrent requests for the same key share one render.
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private nonisolated struct Key: Hashable {
        let source: ThumbnailSource
        let width: Int
        let height: Int
    }

    private let images = NSCache<KeyBox, NSImage>()
    private var inFlight: [Key: Task<NSImage?, Never>] = [:]

    private init() {
        // Bounded memory: a large Organize grid evicts old pages.
        images.countLimit = 400
    }

    func cachedImage(for source: ThumbnailSource, maxPixels: CGSize) -> NSImage? {
        images.object(forKey: KeyBox(key(source, maxPixels)))
    }

    func image(for source: ThumbnailSource, maxPixels: CGSize) async -> NSImage? {
        let key = key(source, maxPixels)
        if let image = images.object(forKey: KeyBox(key)) { return image }
        if let task = inFlight[key] { return await task.value }

        let task = Task<NSImage?, Never> {
            guard let cgImage = await ThumbnailRenderer.render(source, maxPixels: maxPixels) else { return nil }
            return NSImage(cgImage: cgImage, size: .zero)
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image { images.setObject(image, forKey: KeyBox(key)) }
        return image
    }

    private func key(_ source: ThumbnailSource, _ maxPixels: CGSize) -> Key {
        Key(source: source, width: Int(maxPixels.width), height: Int(maxPixels.height))
    }

    /// `NSCache` needs class keys. Nonisolated because it overrides `NSObject` members.
    private nonisolated final class KeyBox: NSObject {
        let key: Key
        init(_ key: Key) { self.key = key }
        override var hash: Int { key.hashValue }
        override func isEqual(_ object: Any?) -> Bool { (object as? KeyBox)?.key == key }
    }
}
