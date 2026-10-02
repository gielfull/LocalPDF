/// Parses "1-3, 5, 8-" style page ranges (1-based, as users type them) into 0-based indices.
///
/// Grammar, per comma-separated part (whitespace around numbers and dashes is ignored):
/// - `5`    a single page
/// - `1-3`  pages 1 through 3, inclusive
/// - `8-`   page 8 through the last page
/// - `-3`   page 1 through page 3
///
/// En and em dashes count as hyphens, since macOS text fields may substitute them.
/// Empty parts (`"1,,2"`, a trailing comma) are skipped. Duplicates are removed,
/// keeping the first occurrence, so `"3, 1-3"` yields `[2, 0, 1]`.
///
/// Throws `PDFEngineError.invalidPageRange` with the offending part for garbage,
/// page 0, a page past `pageCount`, a reversed range like `"5-3"`, or text that
/// contains no pages at all.
public struct PageRange: Codable, Sendable, Hashable {
    /// 0-based page indices, in the order the user listed them, without duplicates.
    public let indices: [Int]

    public init(parsing text: String, pageCount: Int) throws {
        var seen = Set<Int>()
        var result: [Int] = []

        for rawPart in text.split(separator: ",", omittingEmptySubsequences: false) {
            let part = String(rawPart).trimmingWhitespace
            if part.isEmpty { continue }
            let pages = try Self.parsePart(part, pageCount: pageCount)
            for page in pages where seen.insert(page).inserted {
                result.append(page - 1)
            }
        }

        guard !result.isEmpty else {
            throw PDFEngineError.invalidPageRange(text.trimmingWhitespace)
        }
        self.indices = result
    }

    /// Parses one part into 1-based page numbers, validated against `pageCount`.
    private static func parsePart(_ part: String, pageCount: Int) throws -> ClosedRange<Int> {
        let invalid = PDFEngineError.invalidPageRange(part)
        let normalized = part.map { "\u{2013}\u{2014}".contains($0) ? "-" : $0 }
        let pieces = String(normalized)
            .split(separator: "-", omittingEmptySubsequences: false)
            .map { Substring($0.trimmingWhitespace) }

        let lower: Int
        let upper: Int
        switch pieces.count {
        case 1:
            guard let page = Self.pageNumber(pieces[0]) else { throw invalid }
            (lower, upper) = (page, page)
        case 2:
            let (start, end) = (pieces[0], pieces[1])
            guard !(start.isEmpty && end.isEmpty) else { throw invalid }
            guard let from = start.isEmpty ? 1 : Self.pageNumber(start),
                  let to = end.isEmpty ? pageCount : Self.pageNumber(end)
            else { throw invalid }
            (lower, upper) = (from, to)
        default:
            throw invalid
        }

        guard lower >= 1, upper <= pageCount, lower <= upper else { throw invalid }
        return lower...upper
    }

    /// Digits only: rejects signs, decimals and anything `Int(_:)` would otherwise accept.
    private static func pageNumber(_ text: Substring) -> Int? {
        guard !text.isEmpty, text.allSatisfy(\.isASCIIDigit) else { return nil }
        return Int(text)
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}

private extension StringProtocol {
    var trimmingWhitespace: String {
        String(drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
    }
}
