import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import PDFEngine

@Suite("QPDF")
struct QPDFTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    @Test("Streams with indirect /Length: equal data is merged, different data is not")
    func deduplicateIndirectLength() async throws {
        let url = try fixtures.indirectLengthPDF(contents: [0, 0, 0, 1, 1, 1])
        #expect(try #require(PDFDocument(url: url)).pageCount == 6)
        // 4 images (two groups of three), plus 5 of the six pages' identical content streams.
        #expect(try QPDF(url: url).deduplicateStreams() == 4 + 5)

        var options = CompressOperation.Options()
        options.level = .less
        let outputs = try await fixtures.run(CompressOperation(), [InputFile(url: url)], options)
        #expect(try Inspect.fileSize(outputs[0].url) < Inspect.fileSize(url) / 2)
        let document = try #require(CGPDFDocument(outputs[0].url as CFURL))
        #expect(document.numberOfPages == 6)
        var seen = Set<CGPDFStreamRef>()
        let images = (1...6).map { PDFImageXObjects.images(on: document.page(at: $0)!, seen: &seen).count }
        #expect(images == [1, 0, 0, 1, 0, 0], "pages 1-3 share one image, pages 4-6 another")
    }

    @Test("Re-encryption mirrors a user-password open, and refuses an owner-password open")
    func matchingEncryption() throws {
        let url = try fixtures.userOwnerRestrictedScan()
        let asUser = InputFile(url: url, password: "user")
        let asOwner = InputFile(url: url, password: "owner")

        guard case .aes256(let user, let owner, let permissions)? =
            QPDF.Encryption.matching(try DocumentIO.open(asUser), input: asUser) else {
            Issue.record("expected AES-256 for a user-password open")
            return
        }
        #expect(user == "user")
        #expect(owner != "owner" && !owner.isEmpty)
        #expect(permissions & PDFAccessPermissions.allowsContentCopying.rawValue == 0)
        #expect(permissions & PDFAccessPermissions.allowsHighQualityPrinting.rawValue == 0)

        #expect(QPDF.Encryption.matching(try DocumentIO.open(asOwner), input: asOwner) == nil)
    }
}
