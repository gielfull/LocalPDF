/// Resolves a `PageSelection` option into 0-based page indices.
enum PageSelectionResolver {
    /// `nil` (or text that is only whitespace, i.e. an empty field) selects every page;
    /// anything else must parse as a `PageRange`.
    static func indices(_ selection: PageSelection, pageCount: Int) throws -> Set<Int> {
        guard let text = selection, !text.allSatisfy(\.isWhitespace) else {
            return Set(0..<pageCount)
        }
        return Set(try PageRange(parsing: text, pageCount: pageCount).indices)
    }

    /// File-name fragment for a run of pages: "page-4" or "pages-1-3", or `nil` when the
    /// indices aren't one ascending, contiguous run.
    static func nameFragment(for indices: [Int]) -> String? {
        guard let first = indices.first, let last = indices.last else { return nil }
        guard indices == Array(first...max(first, last)) else { return nil }
        return first == last ? "page-\(first + 1)" : "pages-\(first + 1)-\(last + 1)"
    }
}
