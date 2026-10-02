import PDFEngine

/// Keeps a page-range text field and a clickable page grid in sync, both ways.
///
/// Parsing is lenient on purpose: each comma-separated part is checked on its own with
/// `PageRange`, and parts that don't parse yet are skipped, so the grid highlights pages
/// while the user is still typing ("1-3, 5-" highlights 1–3, then 5 onwards).
nonisolated enum PageRangeSync {
    /// 0-based pages mentioned by the valid parts of `text`.
    static func pages(in text: String, pageCount: Int) -> Set<Int> {
        Set(parts(in: text, pageCount: pageCount).keys)
    }

    /// For each mentioned 0-based page, the index of the part that first mentions it.
    /// Split uses this to show which output file each page goes to.
    static func parts(in text: String, pageCount: Int) -> [Int: Int] {
        var result: [Int: Int] = [:]
        var partIndex = 0
        for part in text.split(separator: ",") {
            guard let range = try? PageRange(parsing: String(part), pageCount: pageCount) else { continue }
            for page in range.indices where result[page] == nil {
                result[page] = partIndex
            }
            partIndex += 1
        }
        return result
    }

    /// Canonical text for a set of 0-based pages: consecutive runs collapse, "1-3, 5".
    static func text(for pages: Set<Int>) -> String {
        var runs: [ClosedRange<Int>] = []
        for page in pages.sorted() {
            if let last = runs.last, last.upperBound + 1 == page {
                runs[runs.count - 1] = last.lowerBound...page
            } else {
                runs.append(page...page)
            }
        }
        return runs
            .map { $0.count == 1 ? "\($0.lowerBound + 1)" : "\($0.lowerBound + 1)-\($0.upperBound + 1)" }
            .joined(separator: ", ")
    }

    /// Adds or removes one 0-based page and returns the canonical text.
    static func toggling(_ page: Int, in text: String, pageCount: Int) -> String {
        var selected = pages(in: text, pageCount: pageCount)
        if selected.contains(page) { selected.remove(page) } else { selected.insert(page) }
        return self.text(for: selected)
    }
}
