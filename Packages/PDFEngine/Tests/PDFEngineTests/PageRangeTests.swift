import Foundation
import Testing
@testable import PDFEngine

@Suite("PageRange parsing")
struct PageRangeTests {
    @Test("The documented example")
    func documentedExample() throws {
        #expect(try PageRange(parsing: "1-3, 5, 8-", pageCount: 10).indices == [0, 1, 2, 4, 7, 8, 9])
    }

    @Test("Single forms", arguments: [
        ("5", [4]),
        ("1-3", [0, 1, 2]),
        ("8-", [7, 8, 9]),
        ("-3", [0, 1, 2]),
        ("10", [9]),
        ("10-", [9]),
        ("1-10", Array(0..<10)),
        ("3-3", [2]),
    ])
    func singleForms(text: String, expected: [Int]) throws {
        #expect(try PageRange(parsing: text, pageCount: 10).indices == expected)
    }

    @Test("Whitespace is ignored everywhere")
    func whitespace() throws {
        let range = try PageRange(parsing: "  1 - 3 ,\t5 ,  8 -  ", pageCount: 10)
        #expect(range.indices == [0, 1, 2, 4, 7, 8, 9])
    }

    @Test("En and em dashes act as hyphens")
    func typographicDashes() throws {
        #expect(try PageRange(parsing: "1\u{2013}2, 4\u{2014}5", pageCount: 5).indices == [0, 1, 3, 4])
    }

    @Test("Duplicates are removed, first occurrence wins")
    func deduplicatesPreservingOrder() throws {
        #expect(try PageRange(parsing: "3, 1-3", pageCount: 5).indices == [2, 0, 1])
        #expect(try PageRange(parsing: "2, 2, 2", pageCount: 5).indices == [1])
        #expect(try PageRange(parsing: "4-, 1-5", pageCount: 5).indices == [3, 4, 0, 1, 2])
    }

    @Test("Empty parts between commas are skipped")
    func emptyParts() throws {
        #expect(try PageRange(parsing: "1,,2,", pageCount: 5).indices == [0, 1])
    }

    @Test("Garbage and out-of-range input throws", arguments: [
        "",
        "   ",
        ",,",
        "-",
        "abc",
        "1-2-3",
        "0",
        "0-2",
        "11",
        "9-11",
        "11-",
        "5-3",
        "1.5",
        "+2",
        "1 2",      // whitespace inside a number is garbage, not page 12
        "1;2",
        "\u{0661}", // ARABIC-INDIC DIGIT ONE: numeric, but not a page number we accept
    ])
    func rejects(text: String) {
        #expect(throws: PDFEngineError.self) {
            try PageRange(parsing: text, pageCount: 10)
        }
    }

    @Test("The error carries the offending part")
    func errorNamesOffendingPart() {
        #expect(throws: PDFEngineError.invalidPageRange("12")) {
            try PageRange(parsing: "1-3, 12", pageCount: 10)
        }
    }

    @Test("A document with no pages accepts no range")
    func zeroPages() {
        #expect(throws: PDFEngineError.self) {
            try PageRange(parsing: "1", pageCount: 0)
        }
        #expect(throws: PDFEngineError.self) {
            try PageRange(parsing: "1-", pageCount: 0)
        }
    }

    @Test("Round-trips through Codable")
    func codable() throws {
        let range = try PageRange(parsing: "2-4, 1", pageCount: 5)
        let data = try JSONEncoder().encode(range)
        #expect(try JSONDecoder().decode(PageRange.self, from: data) == range)
    }
}
