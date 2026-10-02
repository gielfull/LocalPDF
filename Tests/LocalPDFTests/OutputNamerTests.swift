import Testing
@testable import LocalPDF

@Suite("Output name collisions")
struct OutputNamerTests {
    @Test("A free name is kept as-is")
    func freeName() {
        #expect(OutputNamer.uniqueName(for: "report.pdf") { _ in false } == "report.pdf")
    }

    @Test("Collisions get \" 2\", \" 3\"… before the extension")
    func suffixes() {
        var taken: Set<String> = ["report.pdf"]
        #expect(OutputNamer.uniqueName(for: "report.pdf", isTaken: taken.contains) == "report 2.pdf")
        taken.insert("report 2.pdf")
        #expect(OutputNamer.uniqueName(for: "report.pdf", isTaken: taken.contains) == "report 3.pdf")
    }

    @Test("Gaps are filled from 2 upward")
    func gaps() {
        let taken: Set<String> = ["a.pdf", "a 3.pdf"]
        #expect(OutputNamer.uniqueName(for: "a.pdf", isTaken: taken.contains) == "a 2.pdf")
    }

    @Test("Names without an extension, and with dots in the base")
    func extensions() {
        #expect(OutputNamer.uniqueName(for: "pages", isTaken: { $0 == "pages" }) == "pages 2")
        #expect(OutputNamer.uniqueName(for: "v1.2 notes.pdf", isTaken: { $0 == "v1.2 notes.pdf" }) == "v1.2 notes 2.pdf")
    }

    @Test("Several outputs saved in a row each get their own name")
    func batch() {
        var taken: Set<String> = ["page.png"]
        var saved: [String] = []
        for _ in 0..<3 {
            let name = OutputNamer.uniqueName(for: "page.png", isTaken: taken.contains)
            taken.insert(name)
            saved.append(name)
        }
        #expect(saved == ["page 2.png", "page 3.png", "page 4.png"])
    }

    @Test("Path separators and empty names are made safe")
    func sanitized() {
        #expect(OutputNamer.sanitized("a/b:c.pdf") == "a-b-c.pdf")
        #expect(OutputNamer.sanitized("  ") == "Untitled")
        #expect(OutputNamer.sanitized(".pdf") == "Untitled.pdf")
    }
}
