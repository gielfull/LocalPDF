import Foundation
import PDFKit
import Testing

extension Fixtures {
    /// A scan that needs the open password "user", and forbids printing, copying and
    /// editing unless opened with the different owner password "owner".
    func userOwnerRestrictedScan(_ name: String = "restricted-scan") throws -> URL {
        let plain = try imagePDF("\(name)-plain", pages: 2, imageSize: CGSize(width: 1700, height: 2200), jpeg: true)
        return try encrypt(plain, as: name, userPassword: "user", ownerPassword: "owner", permissions: 0)
    }
}

extension Inspect {
    /// Checks that `url` is still protected like `Fixtures.userOwnerRestrictedScan`: it opens
    /// with "user", keeps its restrictions under it, and opens with full rights with "owner".
    static func expectUserOwnerProtection(_ url: URL, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let asUser = try #require(PDFDocument(url: url), sourceLocation: sourceLocation)
        #expect(asUser.isLocked, sourceLocation: sourceLocation)
        #expect(!asUser.unlock(withPassword: "wrong"), sourceLocation: sourceLocation)
        #expect(asUser.unlock(withPassword: "user"), sourceLocation: sourceLocation)
        #expect(asUser.permissionsStatus == .user, sourceLocation: sourceLocation)
        #expect(!asUser.allowsPrinting, sourceLocation: sourceLocation)
        #expect(!asUser.allowsCopying, sourceLocation: sourceLocation)
        #expect(!asUser.allowsDocumentChanges, sourceLocation: sourceLocation)

        let asOwner = try #require(PDFDocument(url: url), sourceLocation: sourceLocation)
        #expect(asOwner.unlock(withPassword: "owner"), sourceLocation: sourceLocation)
        #expect(asOwner.permissionsStatus == .owner, sourceLocation: sourceLocation)
        #expect(asOwner.pageCount == 2, sourceLocation: sourceLocation)
    }
}
