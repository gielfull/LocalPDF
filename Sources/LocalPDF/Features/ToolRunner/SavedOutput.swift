import Foundation

/// A result file after it was moved to the output folder.
nonisolated struct SavedOutput: Identifiable, Hashable, Sendable {
    let url: URL
    let byteCount: Int64

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var isPDF: Bool { url.pathExtension.lowercased() == "pdf" }

    var thumbnail: ThumbnailSource {
        ThumbnailSource(url: url, kind: isPDF ? .pdfPage(0) : .image)
    }
}
