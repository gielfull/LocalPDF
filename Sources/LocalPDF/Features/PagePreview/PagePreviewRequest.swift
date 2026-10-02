import Foundation

/// What the page preview shows: some of one file's pages, in an order, starting at one.
///
/// Page grids show pages in different orders (Organize's plan is reordered, rotated and
/// may repeat pages), so the request lists them explicitly and the preview pages through
/// exactly what the grid shows.
nonisolated struct PagePreviewRequest: Identifiable, Sendable {
    struct Item: Hashable, Sendable {
        /// 0-based page in the file.
        let sourceIndex: Int
        /// Extra clockwise rotation the grid applies on top of the page's own.
        var rotation = 0
    }

    let id = UUID()
    let file: SourceFile
    let items: [Item]
    /// Position in `items` to open at.
    let start: Int

    /// Every page of `file`, in order, opening at `page`.
    static func allPages(of file: SourceFile, startingAt page: Int) -> PagePreviewRequest {
        PagePreviewRequest(
            file: file,
            items: (0..<file.pageCount).map { Item(sourceIndex: $0) },
            start: min(max(page, 0), max(file.pageCount - 1, 0))
        )
    }
}
