import Foundation
import PDFKit
import Testing
@testable import PDFEngine

@Suite("Repair")
struct RepairOperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    @Test("A file cut off before its xref table and trailer opens again, every page intact")
    func truncated() async throws {
        let url = try fixtures.damagedPDF(.truncated, pages: 3)
        #expect(PDFDocument(url: url) == nil, "PDFKit shouldn't open the damaged fixture")

        let outputs = try await fixtures.run(RepairOperation(), [InputFile(url: url)], .init())
        #expect(outputs.map(\.suggestedName) == ["localpdf_repair_report.pdf"])
        #expect(try Inspect.texts(outputs[0].url) == ["Page 1", "Page 2", "Page 3"])
    }

    @Test("Wrong cross-reference offsets are rebuilt, bringing back the page content")
    func wrongOffsets() async throws {
        let url = try fixtures.damagedPDF(.wrongOffsets, pages: 4)
        // PDFKit either refuses the file or reads its pages wrong.
        let before = PDFDocument(url: url)
        let textsBefore = before.map { document in
            (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
        }
        #expect(textsBefore != ["Page 1", "Page 2", "Page 3", "Page 4"], "PDFKit should fail on the fixture")

        let outputs = try await fixtures.run(RepairOperation(), [InputFile(url: url)], .init())
        #expect(try Inspect.texts(outputs[0].url) == ["Page 1", "Page 2", "Page 3", "Page 4"])
    }

    @Test("A healthy file comes back with the same pages, rotation and bookmarks")
    func healthy() async throws {
        let url = try fixtures.pdf(pages: 2, rotations: [0, 90])
        let merged = try await fixtures.run(MergeOperation(), [InputFile(url: url), InputFile(url: url)], .init())
        let outputs = try await fixtures.run(RepairOperation(), [InputFile(url: merged[0].url)], .init())
        #expect(try Inspect.texts(outputs[0].url) == ["Page 1", "Page 2", "Page 1", "Page 2"])
        #expect(try Inspect.rotations(outputs[0].url) == [0, 90, 0, 90])
        #expect(try Inspect.document(outputs[0].url).outlineRoot?.numberOfChildren == 2)
    }

    @Test("Each input is repaired on its own")
    func batch() async throws {
        let first = try fixtures.damagedPDF(.truncated, "first", pages: 1)
        let second = try fixtures.damagedPDF(.wrongOffsets, "second", pages: 2)
        let outputs = try await fixtures.run(
            RepairOperation(), [InputFile(url: first), InputFile(url: second)], .init())
        #expect(outputs.map(\.suggestedName) == ["localpdf_repair_first.pdf", "localpdf_repair_second.pdf"])
        #expect(try Inspect.texts(outputs) == [["Page 1"], ["Page 1", "Page 2"]])
    }

    @Test("An encrypted input stays encrypted, and needs its password")
    func encrypted() async throws {
        let url = try fixtures.encryptedPDF(pages: 2, password: "pw")
        await #expect(throws: PDFEngineError.passwordRequired(url)) {
            try await RepairOperation().run([InputFile(url: url)], options: .init()) { _ in }
        }
        await #expect(throws: PDFEngineError.wrongPassword(url)) {
            try await RepairOperation().run([InputFile(url: url, password: "nope")], options: .init()) { _ in }
        }
        let outputs = try await fixtures.run(RepairOperation(), [InputFile(url: url, password: "pw")], .init())
        let document = try #require(PDFDocument(url: outputs[0].url))
        #expect(document.isLocked)
        #expect(document.unlock(withPassword: "pw"))
        #expect(document.page(at: 1)?.string?.contains("Page 2") == true)
    }

    @Test("Unlocked with the owner password, the output keeps the open password and restrictions")
    func ownerPassword() async throws {
        let url = try fixtures.userOwnerRestrictedScan()
        let outputs = try await fixtures.run(RepairOperation(), [InputFile(url: url, password: "owner")], .init())
        try Inspect.expectUserOwnerProtection(outputs[0].url)
    }

    @Test("A file that isn't a PDF can't be repaired")
    func notAPDF() async throws {
        let url = try fixtures.textFile()
        await #expect(throws: PDFEngineError.cannotOpen(url)) {
            try await RepairOperation().run([InputFile(url: url)], options: .init()) { _ in }
        }
    }
}
