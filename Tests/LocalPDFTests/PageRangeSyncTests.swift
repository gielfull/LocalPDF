import Testing
@testable import LocalPDF

@Suite("Page range ↔ page selection")
struct PageRangeSyncTests {
    @Test("Typed ranges select the matching 0-based pages")
    func textToPages() {
        #expect(PageRangeSync.pages(in: "1-3, 5", pageCount: 10) == [0, 1, 2, 4])
        #expect(PageRangeSync.pages(in: "8-", pageCount: 10) == [7, 8, 9])
        #expect(PageRangeSync.pages(in: "", pageCount: 10).isEmpty)
    }

    @Test("Half-typed and invalid parts are skipped, so highlighting follows typing")
    func lenient() {
        #expect(PageRangeSync.pages(in: "1-3, 5-x", pageCount: 10) == [0, 1, 2])
        #expect(PageRangeSync.pages(in: "2, 99", pageCount: 10) == [1])
        #expect(PageRangeSync.pages(in: "1-3,", pageCount: 10) == [0, 1, 2])
    }

    @Test("Selections become canonical text with runs collapsed")
    func pagesToText() {
        #expect(PageRangeSync.text(for: [0, 1, 2, 4]) == "1-3, 5")
        #expect(PageRangeSync.text(for: [9]) == "10")
        #expect(PageRangeSync.text(for: [3, 1, 2, 7, 8]) == "2-4, 8-9")
        #expect(PageRangeSync.text(for: []) == "")
    }

    @Test("Clicking a page toggles it in the text")
    func toggling() {
        #expect(PageRangeSync.toggling(3, in: "1-3", pageCount: 10) == "1-4")
        #expect(PageRangeSync.toggling(1, in: "1-3", pageCount: 10) == "1, 3")
        #expect(PageRangeSync.toggling(0, in: "", pageCount: 10) == "1")
        #expect(PageRangeSync.toggling(0, in: "1", pageCount: 10) == "")
    }

    @Test("Round trip: text → pages → text is stable for canonical text")
    func roundTrip() {
        for text in ["1-3, 5", "2", "4-6, 8-10", "1, 3, 5"] {
            #expect(PageRangeSync.text(for: PageRangeSync.pages(in: text, pageCount: 10)) == text)
        }
    }

    @Test("Each part maps its pages to an output file, first mention wins")
    func parts() {
        let parts = PageRangeSync.parts(in: "1-2, 4, 2-3", pageCount: 5)
        #expect(parts == [0: 0, 1: 0, 3: 1, 2: 2])
    }
}
