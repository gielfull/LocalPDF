import Foundation
import PDFKit
import Testing
@testable import PDFEngine

@Suite("Merge")
struct MergeOperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    @Test("Concatenates inputs in the given order")
    func order() async throws {
        let a = try fixtures.pdf("alpha", pages: 3, label: "A")
        let b = try fixtures.pdf("beta", pages: 2, label: "B")
        let outputs = try await fixtures.run(MergeOperation(), [InputFile(url: b), InputFile(url: a)], .init())
        #expect(outputs.count == 1)
        #expect(outputs[0].suggestedName == "localpdf_merge_beta.pdf")
        #expect(try Inspect.texts(outputs[0].url) == ["B 1", "B 2", "A 1", "A 2", "A 3"])
    }

    @Test("Adds one bookmark per file pointing at its first page")
    func bookmarks() async throws {
        let a = try fixtures.pdf("alpha", pages: 3, label: "A")
        let b = try fixtures.pdf("beta", pages: 2, label: "B")
        let outputs = try await fixtures.run(MergeOperation(), [InputFile(url: a), InputFile(url: b)], .init())
        let document = try Inspect.document(outputs[0].url)
        let root = try #require(document.outlineRoot)
        #expect(root.numberOfChildren == 2)
        let labels = (0..<root.numberOfChildren).map { root.child(at: $0)?.label }
        #expect(labels == ["alpha", "beta"])
        let targets = (0..<root.numberOfChildren).map { index -> Int? in
            guard let page = root.child(at: index)?.destination?.page else { return nil }
            return document.index(for: page)
        }
        #expect(targets == [0, 3])
    }

    @Test("Without bookmarks there is no outline")
    func noBookmarks() async throws {
        let a = try fixtures.pdf("alpha", pages: 1)
        let b = try fixtures.pdf("beta", pages: 1)
        var options = MergeOperation.Options()
        options.addBookmarks = false
        let outputs = try await fixtures.run(MergeOperation(), [InputFile(url: a), InputFile(url: b)], options)
        let root = try Inspect.document(outputs[0].url).outlineRoot
        #expect((root?.numberOfChildren ?? 0) == 0)
    }

    @Test("A source's own bookmarks nest under its file entry, remapped to the merged pages")
    func nestedOutline() async throws {
        let a = try fixtures.pdf("alpha", pages: 2, label: "A")
        let bookmarked = try fixtures.pdf("beta", pages: 3, label: "B")
        try fixtures.modify(bookmarked) { source in
            let root = PDFOutline()
            let chapter = PDFOutline()
            chapter.label = "Chapter 3"
            chapter.destination = PDFDestination(page: try #require(source.page(at: 2)), at: .zero)
            root.insertChild(chapter, at: 0)
            source.outlineRoot = root
        }

        let outputs = try await fixtures.run(
            MergeOperation(), [InputFile(url: a), InputFile(url: bookmarked)], .init())
        let merged = try Inspect.document(outputs[0].url)
        let betaEntry = try #require(merged.outlineRoot?.child(at: 1))
        let nested = try #require(betaEntry.child(at: 0))
        #expect(nested.label == "Chapter 3")
        let target = try #require(nested.destination?.page)
        #expect(merged.index(for: target) == 4) // 2 alpha pages + beta page 3
    }

    @Test("The same file twice is two inputs")
    func sameFileTwice() async throws {
        let a = try fixtures.pdf("alpha", pages: 2, label: "A")
        let outputs = try await fixtures.run(MergeOperation(), [InputFile(url: a), InputFile(url: a)], .init())
        #expect(try Inspect.texts(outputs[0].url) == ["A 1", "A 2", "A 1", "A 2"])
    }

    @Test("Needs at least two inputs")
    func singleInput() async throws {
        let a = try fixtures.pdf("alpha", pages: 2)
        await #expect(throws: PDFEngineError.unsupportedInput(a)) {
            try await MergeOperation().run([InputFile(url: a)], options: .init()) { _ in }
        }
    }

    @Test("A locked input without its password fails, naming that file")
    func lockedInput() async throws {
        let a = try fixtures.pdf("alpha", pages: 1)
        let locked = try fixtures.encryptedPDF(pages: 1, password: "pw")
        await #expect(throws: PDFEngineError.passwordRequired(locked)) {
            try await MergeOperation().run([InputFile(url: a), InputFile(url: locked)], options: .init()) { _ in }
        }
    }
}

@Suite("Split")
struct SplitOperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    @Test("Custom ranges make one file per part")
    func customRanges() async throws {
        let url = try fixtures.pdf(pages: 5)
        var options = SplitOperation.Options()
        options.mode = .customRanges("1-2, 3, 4-")
        let outputs = try await fixtures.run(SplitOperation(), [InputFile(url: url)], options)
        #expect(outputs.map(\.suggestedName) == [
            "localpdf_split_report_pages-1-2.pdf", "localpdf_split_report_page-3.pdf", "localpdf_split_report_pages-4-5.pdf",
        ])
        #expect(try Inspect.texts(outputs) == [["Page 1", "Page 2"], ["Page 3"], ["Page 4", "Page 5"]])
    }

    @Test("Every N pages, with a shorter last chunk")
    func everyN() async throws {
        let url = try fixtures.pdf(pages: 5)
        var options = SplitOperation.Options()
        options.mode = .everyNPages(2)
        let outputs = try await fixtures.run(SplitOperation(), [InputFile(url: url)], options)
        #expect(try Inspect.texts(outputs) == [["Page 1", "Page 2"], ["Page 3", "Page 4"], ["Page 5"]])
    }

    @Test("Each page becomes its own file")
    func eachPage() async throws {
        let url = try fixtures.pdf(pages: 3, rotations: [0, 90, 0])
        let outputs = try await fixtures.run(SplitOperation(), [InputFile(url: url)], .init())
        #expect(outputs.map(\.suggestedName) == [
            "localpdf_split_report_page-1.pdf", "localpdf_split_report_page-2.pdf", "localpdf_split_report_page-3.pdf",
        ])
        #expect(try Inspect.texts(outputs) == [["Page 1"], ["Page 2"], ["Page 3"]])
        #expect(try Inspect.rotations(outputs[1].url) == [90])
    }

    @Test("A bad range throws and names the part", arguments: [
        (SplitOperation.Mode.customRanges("1-2, 9"), "9"),
        (.customRanges("4-2"), "4-2"),
        (.customRanges(" , "), " , "),
        (.everyNPages(0), "0"),
    ])
    func badRange(mode: SplitOperation.Mode, part: String) async throws {
        let url = try fixtures.pdf(pages: 5)
        var options = SplitOperation.Options()
        options.mode = mode
        await #expect(throws: PDFEngineError.invalidPageRange(part)) {
            try await SplitOperation().run([InputFile(url: url)], options: options) { _ in }
        }
    }

    @Test("Takes exactly one input")
    func twoInputs() async throws {
        let a = try fixtures.pdf("a", pages: 2)
        let b = try fixtures.pdf("b", pages: 2)
        await #expect(throws: PDFEngineError.unsupportedInput(b)) {
            try await SplitOperation().run([InputFile(url: a), InputFile(url: b)], options: .init()) { _ in }
        }
    }

    @Test("A file that isn't a PDF can't be opened")
    func notAPDF() async throws {
        let url = try fixtures.textFile()
        await #expect(throws: PDFEngineError.cannotOpen(url)) {
            try await SplitOperation().run([InputFile(url: url)], options: .init()) { _ in }
        }
    }
}

@Suite("Remove Pages")
struct RemovePagesOperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    @Test("Keeps the other pages in order")
    func removes() async throws {
        let url = try fixtures.pdf(pages: 5)
        var options = RemovePagesOperation.Options()
        options.pages = "4, 2"
        let outputs = try await fixtures.run(RemovePagesOperation(), [InputFile(url: url)], options)
        #expect(outputs.map(\.suggestedName) == ["localpdf_remove-pages_report.pdf"])
        #expect(try Inspect.texts(outputs[0].url) == ["Page 1", "Page 3", "Page 5"])
    }

    @Test("Removing every page is an error")
    func removeAll() async throws {
        let url = try fixtures.pdf(pages: 3)
        var options = RemovePagesOperation.Options()
        options.pages = "1-"
        await #expect(throws: PDFEngineError.invalidPageRange("1-")) {
            try await RemovePagesOperation().run([InputFile(url: url)], options: options) { _ in }
        }
    }

    @Test("A bad range throws")
    func badRange() async throws {
        let url = try fixtures.pdf(pages: 3)
        var options = RemovePagesOperation.Options()
        options.pages = "2, 7"
        await #expect(throws: PDFEngineError.invalidPageRange("7")) {
            try await RemovePagesOperation().run([InputFile(url: url)], options: options) { _ in }
        }
    }
}

@Suite("Extract Pages")
struct ExtractPagesOperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    @Test("One file, pages in the order typed")
    func singleFile() async throws {
        let url = try fixtures.pdf(pages: 5)
        var options = ExtractPagesOperation.Options()
        options.pages = "4, 1-2"
        let outputs = try await fixtures.run(ExtractPagesOperation(), [InputFile(url: url)], options)
        #expect(outputs.map(\.suggestedName) == ["localpdf_extract-pages_report.pdf"])
        #expect(try Inspect.texts(outputs[0].url) == ["Page 4", "Page 1", "Page 2"])
    }

    @Test("A contiguous run is named after its pages")
    func contiguousName() async throws {
        let url = try fixtures.pdf(pages: 5)
        var options = ExtractPagesOperation.Options()
        options.pages = "1-3"
        let outputs = try await fixtures.run(ExtractPagesOperation(), [InputFile(url: url)], options)
        #expect(outputs.map(\.suggestedName) == ["localpdf_extract-pages_report_pages-1-3.pdf"])
    }

    @Test("Separate files, one per page")
    func separateFiles() async throws {
        let url = try fixtures.pdf(pages: 5)
        var options = ExtractPagesOperation.Options()
        options.pages = "5, 2"
        options.separateFiles = true
        let outputs = try await fixtures.run(ExtractPagesOperation(), [InputFile(url: url)], options)
        #expect(outputs.map(\.suggestedName) == ["localpdf_extract-pages_report_page-5.pdf", "localpdf_extract-pages_report_page-2.pdf"])
        #expect(try Inspect.texts(outputs) == [["Page 5"], ["Page 2"]])
    }

    @Test("Internal links follow their target, or go when it's left out")
    func links() async throws {
        let url = try fixtures.pdf(pages: 3)
        try fixtures.modify(url) { source in
            let link = PDFAnnotation(bounds: CGRect(x: 72, y: 72, width: 100, height: 20),
                                     forType: .link, withProperties: nil)
            link.destination = PDFDestination(page: try #require(source.page(at: 2)), at: CGPoint(x: 0, y: 792))
            try #require(source.page(at: 0)).addAnnotation(link)
        }

        var options = ExtractPagesOperation.Options()
        options.pages = "1, 3"
        let kept = try await fixtures.run(ExtractPagesOperation(), [InputFile(url: url)], options)
        let document = try Inspect.document(kept[0].url)
        let links = try #require(document.page(at: 0)).annotations.filter { $0.type == "Link" }
        #expect(links.count == 1)
        let target = try #require(links.first?.destination?.page)
        #expect(document.index(for: target) == 1)

        options.pages = "1"
        let dropped = try await fixtures.run(ExtractPagesOperation(), [InputFile(url: url)], options)
        let alone = try Inspect.document(dropped[0].url)
        #expect(try #require(alone.page(at: 0)).annotations.filter { $0.type == "Link" }.isEmpty)
    }
}

@Suite("Organize")
struct OrganizeOperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    typealias Step = OrganizeOperation.PageInstruction

    @Test("Reorders, duplicates, rotates and inserts blank pages")
    func plan() async throws {
        let url = try fixtures.pdf(pages: 3, sizes: [CGSize(width: 612, height: 792), CGSize(width: 842, height: 595)],
                                   rotations: [0, 0, 90])
        var options = OrganizeOperation.Options()
        options.pages = [
            Step(sourcePageIndex: 2),                           // Page 3, already at 90
            Step(sourcePageIndex: 1, additionalRotation: 90),   // Page 2, landscape → turned
            Step(sourcePageIndex: nil),                         // blank, like page 2 as displayed
            Step(sourcePageIndex: 0),
            Step(sourcePageIndex: 0, additionalRotation: 450),  // duplicate, 450 ≡ 90
            Step(sourcePageIndex: 2, additionalRotation: -90),  // 90 - 90 = 0
        ]
        let outputs = try await fixtures.run(OrganizeOperation(), [InputFile(url: url)], options)
        #expect(outputs.map(\.suggestedName) == ["localpdf_organize_report.pdf"])
        #expect(try Inspect.texts(outputs[0].url) == ["Page 3", "Page 2", "", "Page 1", "Page 1", "Page 3"])
        #expect(try Inspect.rotations(outputs[0].url) == [90, 90, 0, 0, 90, 0])

        // Page 2 is 842 × 595 turned 90°, so it reads 595 × 842; the blank copies that.
        let blank = try Inspect.box(.mediaBox, of: outputs[0].url, page: 2)
        #expect(blank.size == CGSize(width: 595, height: 842))
    }

    @Test("A leading blank page is US Letter")
    func leadingBlank() async throws {
        let url = try fixtures.pdf(pages: 1, sizes: [CGSize(width: 300, height: 300)])
        var options = OrganizeOperation.Options()
        options.pages = [Step(sourcePageIndex: nil), Step(sourcePageIndex: 0)]
        let outputs = try await fixtures.run(OrganizeOperation(), [InputFile(url: url)], options)
        #expect(try Inspect.box(.mediaBox, of: outputs[0].url, page: 0).size == CGSize(width: 612, height: 792))
        #expect(try Inspect.texts(outputs[0].url) == ["", "Page 1"])
    }

    @Test("An out-of-range page or an empty plan is rejected")
    func invalidPlans() async throws {
        let url = try fixtures.pdf(pages: 2)
        var options = OrganizeOperation.Options()
        options.pages = [Step(sourcePageIndex: 0), Step(sourcePageIndex: 2)]
        await #expect(throws: PDFEngineError.invalidPageRange("3")) {
            try await OrganizeOperation().run([InputFile(url: url)], options: options) { _ in }
        }
        options.pages = []
        await #expect(throws: PDFEngineError.invalidPageRange("")) {
            try await OrganizeOperation().run([InputFile(url: url)], options: options) { _ in }
        }
    }
}
