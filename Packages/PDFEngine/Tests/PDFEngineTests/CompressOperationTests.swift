import Foundation
import PDFKit
import Testing
@testable import PDFEngine

@Suite("Compress")
struct CompressOperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    private func options(_ level: CompressOperation.Level) -> CompressOperation.Options {
        var options = CompressOperation.Options()
        options.level = level
        return options
    }

    /// One high-quality 200 dpi JPEG per Letter page and no text: a typical scan. (PDFKit
    /// leaves images at or below ~150 dpi alone, so a lower-resolution scan wouldn't shrink
    /// at `.recommended`.)
    private func scan(_ name: String = "scan", pages: Int = 1) throws -> URL {
        try fixtures.imagePDF(name, pages: pages, imageSize: CGSize(width: 1700, height: 2200), jpeg: true)
    }

    @Test("Never larger; when nothing is gained, a byte-identical copy",
          arguments: CompressOperation.Level.allCases)
    func neverLarger(level: CompressOperation.Level) async throws {
        let url = try fixtures.pdf(pages: 5)
        let outputs = try await fixtures.run(CompressOperation(), [InputFile(url: url)], options(level))
        #expect(outputs.map(\.suggestedName) == ["localpdf_compress_report.pdf"])
        let size = try Inspect.fileSize(outputs[0].url)
        let original = try Inspect.fileSize(url)
        #expect(size <= original)
        if size == original {
            #expect(try Data(contentsOf: outputs[0].url) == Data(contentsOf: url))
        }
        #expect(try Inspect.texts(outputs[0].url) == (1...5).map { "Page \($0)" })
    }

    @Test("Recommended shrinks image-heavy files; extreme shrinks them further")
    func levels() async throws {
        let url = try scan(pages: 2)
        let original = try Inspect.fileSize(url)
        let recommended = try await fixtures.run(CompressOperation(), [InputFile(url: url)], options(.recommended))
        let extreme = try await fixtures.run(CompressOperation(), [InputFile(url: url)], options(.extreme))
        let recommendedSize = try Inspect.fileSize(recommended[0].url)
        let extremeSize = try Inspect.fileSize(extreme[0].url)
        #expect(recommendedSize < original * 3 / 4, "recommended: \(recommendedSize) of \(original)")
        #expect(extremeSize < recommendedSize, "extreme: \(extremeSize), recommended: \(recommendedSize)")
        for output in recommended + extreme {
            #expect(try Inspect.document(output.url).pageCount == 2)
            #expect(try Inspect.box(.mediaBox, of: output.url, page: 1).size == CGSize(width: 612, height: 792))
        }
    }

    @Test("Extreme keeps rotation, bookmarks, and pages with text as text")
    func extremeKeepsStructure() async throws {
        let scanURL = try scan()
        try fixtures.modify(scanURL) { $0.page(at: 0)?.rotation = 90 }
        let mixed = try fixtures.mixedImagePDF(jpegSize: CGSize(width: 1600, height: 1200),
                                               flateSize: CGSize(width: 800, height: 600))
        // Merge adds an outline entry per file, pointing at the scan and the mixed page.
        let merged = try await fixtures.run(
            MergeOperation(), [InputFile(url: scanURL), InputFile(url: mixed)], .init())
        let combined = merged[0].url

        let outputs = try await fixtures.run(CompressOperation(), [InputFile(url: combined)], options(.extreme))
        #expect(try Inspect.fileSize(outputs[0].url) < Inspect.fileSize(combined))
        #expect(try Inspect.rotations(outputs[0].url) == [90, 0])
        #expect(try Inspect.texts(outputs[0].url) == ["", "Images inside"])
        let document = try Inspect.document(outputs[0].url)
        let root = try #require(document.outlineRoot)
        #expect(root.numberOfChildren == 2)
        let targets = try (0..<2).map { document.index(for: try #require(root.child(at: $0)?.destination?.page)) }
        #expect(targets == [0, 1])
    }

    @Test("An encrypted input stays encrypted with the same password")
    func keepsPassword() async throws {
        let url = try fixtures.encrypt(try scan("plain-scan"), as: "locked-scan",
                                       userPassword: "pw", ownerPassword: "owner")
        let outputs = try await fixtures.run(
            CompressOperation(), [InputFile(url: url, password: "pw")], options(.recommended))
        #expect(try Inspect.fileSize(outputs[0].url) < Inspect.fileSize(url))
        let document = try #require(PDFDocument(url: outputs[0].url))
        #expect(document.isLocked)
        #expect(document.unlock(withPassword: "pw"))
    }

    @Test("Permission restrictions survive compression")
    func keepsRestrictions() async throws {
        let url = try fixtures.encrypt(try scan("plain-scan"), as: "restricted-scan",
                                       userPassword: nil, ownerPassword: "owner", permissions: 0)
        let outputs = try await fixtures.run(CompressOperation(), [InputFile(url: url)], options(.recommended))
        #expect(try Inspect.fileSize(outputs[0].url) < Inspect.fileSize(url))
        let document = try #require(PDFDocument(url: outputs[0].url))
        #expect(document.isEncrypted)
        #expect(!document.isLocked)
        #expect(!document.allowsCopying)
        #expect(!document.allowsPrinting)
    }

    @Test("A locked input without its password fails")
    func passwordRequired() async throws {
        let url = try fixtures.encryptedPDF(pages: 1, password: "pw")
        await #expect(throws: PDFEngineError.passwordRequired(url)) {
            try await CompressOperation().run([InputFile(url: url)], options: .init()) { _ in }
        }
    }

    // MARK: - Structural pass (qpdf)

    @Test("Text-heavy files shrink at every level, text intact",
          arguments: CompressOperation.Level.allCases)
    func textHeavy(level: CompressOperation.Level) async throws {
        let url = try fixtures.textHeavyPDF(pages: 20)
        let outputs = try await fixtures.run(CompressOperation(), [InputFile(url: url)], options(level))
        let size = try Inspect.fileSize(outputs[0].url)
        let original = try Inspect.fileSize(url)
        #expect(size < original * 4 / 5, "\(level): \(size) of \(original)")
        let texts = try Inspect.texts(outputs[0].url)
        #expect(texts.count == 20)
        #expect(texts.enumerated().allSatisfy { $1.hasPrefix("Chapter \($0 + 1)") })
        #expect(try Inspect.texts(outputs[0].url) == Inspect.texts(url))
    }

    @Test("Images and fonts repeated on every page are stored once")
    func duplicates() async throws {
        let url = try fixtures.duplicatedResourcesPDF(copies: 8)
        let outputs = try await fixtures.run(CompressOperation(), [InputFile(url: url)], options(.less))
        #expect(try Inspect.fileSize(outputs[0].url) < Inspect.fileSize(url) / 4)
        #expect(try Inspect.texts(outputs[0].url) == Array(repeating: "Letterhead", count: 8))
    }

    @Test("The structural pass keeps rotation and bookmarks")
    func structureKeepsLayout() async throws {
        let book = try fixtures.textHeavyPDF(pages: 3)
        try fixtures.modify(book) { $0.page(at: 1)?.rotation = 270 }
        // Merge adds an outline entry per file.
        let merged = try await fixtures.run(
            MergeOperation(), [InputFile(url: book), InputFile(url: try fixtures.pdf(pages: 1))], .init())
        let combined = merged[0].url

        let outputs = try await fixtures.run(CompressOperation(), [InputFile(url: combined)], options(.recommended))
        #expect(try Inspect.fileSize(outputs[0].url) < Inspect.fileSize(combined))
        #expect(try Inspect.rotations(outputs[0].url) == [0, 270, 0, 0])
        #expect(try Inspect.texts(outputs[0].url) == Inspect.texts(combined))
        let document = try Inspect.document(outputs[0].url)
        let root = try #require(document.outlineRoot)
        let targets = try (0..<root.numberOfChildren).map {
            document.index(for: try #require(root.child(at: $0)?.destination?.page))
        }
        #expect(targets == [0, 3])
    }

    @Test("A text-heavy encrypted file shrinks and keeps its password and restrictions")
    func structureKeepsEncryption() async throws {
        let book = try fixtures.textHeavyPDF(pages: 10)
        let locked = try fixtures.encrypt(book, as: "locked-book", userPassword: "pw", ownerPassword: "owner",
                                          permissions: 0)
        let outputs = try await fixtures.run(
            CompressOperation(), [InputFile(url: locked, password: "pw")], options(.recommended))
        #expect(try Inspect.fileSize(outputs[0].url) < Inspect.fileSize(locked))
        let document = try #require(PDFDocument(url: outputs[0].url))
        #expect(document.isLocked)
        #expect(!document.unlock(withPassword: "wrong"))
        #expect(document.unlock(withPassword: "pw"))
        #expect(!document.allowsCopying)
        #expect(!document.allowsPrinting)
        #expect(document.page(at: 9)?.string?.hasPrefix("Chapter 10") == true)
    }

    @Test("Unlocked with the owner password, the output keeps the open password and restrictions",
          arguments: CompressOperation.Level.allCases)
    func ownerPassword(level: CompressOperation.Level) async throws {
        let url = try fixtures.userOwnerRestrictedScan()
        let outputs = try await fixtures.run(
            CompressOperation(), [InputFile(url: url, password: "owner")], options(level))
        #expect(try Inspect.fileSize(outputs[0].url) <= Inspect.fileSize(url))
        try Inspect.expectUserOwnerProtection(outputs[0].url)
    }

    @Test("Unlocked with the user password, the output keeps the open password and restrictions",
          arguments: CompressOperation.Level.allCases)
    func userPassword(level: CompressOperation.Level) async throws {
        let url = try fixtures.userOwnerRestrictedScan()
        let outputs = try await fixtures.run(
            CompressOperation(), [InputFile(url: url, password: "user")], options(level))
        let document = try #require(PDFDocument(url: outputs[0].url))
        #expect(document.unlock(withPassword: "user"))
        #expect(document.permissionsStatus == .user)
        #expect(!document.allowsPrinting)
        #expect(!document.allowsCopying)
    }
}
