import PDFEngine
import Testing
@testable import LocalPDF

@Suite("Smart suggestions")
struct SmartSuggestionsTests {
    @Test("One ordinary PDF suggests Organize, Split, Compress, Unlock")
    func singlePDF() {
        #expect(SmartSuggestions.tools(for: [.fixture("a.pdf")]) == [.organize, .split, .compress, .unlock])
    }

    @Test("Two PDFs suggest Merge first, and no single-file tools")
    func twoPDFs() {
        let tools = SmartSuggestions.tools(for: [.fixture("a.pdf"), .fixture("b.pdf")])
        #expect(tools == [.merge, .compress, .unlock])
    }

    @Test("A PDF over 5 MB puts Compress first")
    func largePDF() {
        let tools = SmartSuggestions.tools(for: [.fixture("big.pdf", megabytes: 12)])
        #expect(tools == [.compress, .organize, .split, .unlock])
    }

    @Test("Exactly 5 MB is not large")
    func thresholdIsExclusive() {
        let tools = SmartSuggestions.tools(for: [.fixture("edge.pdf", megabytes: 5)])
        #expect(tools.first == .organize)
    }

    @Test("Large PDFs plus several files: Merge, then Compress, no duplicates")
    func mergeAndCompress() {
        let tools = SmartSuggestions.tools(for: [.fixture("a.pdf", megabytes: 8), .fixture("b.pdf")])
        #expect(tools == [.merge, .compress, .unlock])
    }

    @Test("An encrypted PDF suggests Unlock first")
    func encrypted() {
        let tools = SmartSuggestions.tools(for: [.fixture("secret.pdf", encrypted: true)])
        #expect(tools.first == .unlock)
    }

    @Test("A scanned PDF suggests OCR first")
    func scanned() {
        #expect(SmartSuggestions.tools(for: [.fixture("scan.pdf", scanned: true)])
            == [.ocr, .organize, .split, .compress, .unlock])
        let tools = SmartSuggestions.tools(for: [.fixture("a.pdf"), .fixture("scan.pdf", scanned: true)])
        #expect(tools == [.ocr, .merge, .compress, .unlock])
    }

    @Test("OCR preloads only the scanned PDFs, or every PDF when none looks scanned")
    func filesForOCR() {
        let scan = SourceFile.fixture("scan.pdf", scanned: true)
        let text = SourceFile.fixture("text.pdf")
        let image = SourceFile.fixture("c.png", kind: .image)
        #expect(SmartSuggestions.files([text, image, scan], for: .ocr).map(\.id) == [scan.id])
        #expect(SmartSuggestions.files([text, image], for: .ocr).map(\.id) == [text.id])
    }

    @Test("Images suggest Images to PDF")
    func images() {
        let tools = SmartSuggestions.tools(for: [.fixture("a.png", kind: .image), .fixture("b.png", kind: .image)])
        #expect(tools == [.imagesToPDF])
    }

    @Test("PDFs and images together get both sets")
    func mixed() {
        let tools = SmartSuggestions.tools(for: [.fixture("a.pdf"), .fixture("b.jpg", kind: .image)])
        #expect(tools == [.organize, .split, .compress, .unlock, .imagesToPDF])
    }

    @Test("Unsupported files suggest nothing")
    func unsupported() {
        #expect(SmartSuggestions.tools(for: [.fixture("notes.txt", kind: .other)]).isEmpty)
        #expect(SmartSuggestions.tools(for: []).isEmpty)
    }

    @Test("A suggestion preloads only the files its tool accepts")
    func filesForTool() {
        let pdf = SourceFile.fixture("a.pdf")
        let other = SourceFile.fixture("b.pdf")
        let image = SourceFile.fixture("c.png", kind: .image)
        let all = [pdf, image, other]

        #expect(SmartSuggestions.files(all, for: .merge).map(\.id) == [pdf.id, other.id])
        #expect(SmartSuggestions.files(all, for: .imagesToPDF).map(\.id) == [image.id])
        // Single-input tools take the first accepted file.
        #expect(SmartSuggestions.files(all, for: .split).map(\.id) == [pdf.id])
    }

    @Test("Unlock preloads only the encrypted PDFs")
    func filesForUnlock() {
        let plain = SourceFile.fixture("a.pdf")
        let locked = SourceFile.fixture("b.pdf", encrypted: true, locked: true)
        #expect(SmartSuggestions.files([plain, locked], for: .unlock).map(\.id) == [locked.id])
    }
}
