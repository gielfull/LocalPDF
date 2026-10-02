import Foundation
import PDFKit
import Testing
@testable import PDFEngine

@Suite("Protect")
struct ProtectOperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    @Test("The output needs the password to open")
    func locked() async throws {
        let url = try fixtures.pdf(pages: 2)
        var options = ProtectOperation.Options()
        options.userPassword = "hunter2"
        let outputs = try await fixtures.run(ProtectOperation(), [InputFile(url: url)], options)
        #expect(outputs.map(\.suggestedName) == ["localpdf_protect_report.pdf"])

        let document = try #require(PDFDocument(url: outputs[0].url))
        #expect(document.isEncrypted)
        #expect(document.isLocked)
        #expect(!document.unlock(withPassword: "wrong"))
        #expect(document.unlock(withPassword: "hunter2"))
        #expect(document.pageCount == 2)
        #expect(document.page(at: 1)?.string?.contains("Page 2") == true)
    }

    @Test("Permissions bind when the owner password differs")
    func permissions() async throws {
        let url = try fixtures.pdf(pages: 1)
        var options = ProtectOperation.Options()
        options.userPassword = "reader"
        options.ownerPassword = "owner"
        options.allowCopying = false
        options.allowEditing = false
        let outputs = try await fixtures.run(ProtectOperation(), [InputFile(url: url)], options)

        let asReader = try Inspect.document(outputs[0].url, password: "reader")
        #expect(asReader.allowsPrinting)
        #expect(!asReader.allowsCopying)
        #expect(!asReader.allowsDocumentChanges)
        #expect(!asReader.allowsDocumentAssembly)

        let asOwner = try Inspect.document(outputs[0].url, password: "owner")
        #expect(asOwner.allowsCopying)
    }

    @Test("Printing can be forbidden")
    func noPrinting() async throws {
        let url = try fixtures.pdf(pages: 1)
        var options = ProtectOperation.Options()
        options.userPassword = "reader"
        options.ownerPassword = "owner"
        options.allowPrinting = false
        let outputs = try await fixtures.run(ProtectOperation(), [InputFile(url: url)], options)
        let asReader = try Inspect.document(outputs[0].url, password: "reader")
        #expect(!asReader.allowsPrinting)
        #expect(asReader.allowsCopying)
    }

    @Test("Re-protecting replaces the old password")
    func reprotect() async throws {
        let url = try fixtures.encryptedPDF(pages: 1, password: "old")
        var options = ProtectOperation.Options()
        options.userPassword = "new"
        let outputs = try await fixtures.run(ProtectOperation(), [InputFile(url: url, password: "old")], options)
        let document = try #require(PDFDocument(url: outputs[0].url))
        #expect(!document.unlock(withPassword: "old"))
        #expect(document.unlock(withPassword: "new"))
    }

    @Test("Encryption is AES-256: security handler V5 R6, AESV3 crypt filter")
    func aes256() async throws {
        let url = try fixtures.pdf(pages: 1)
        var options = ProtectOperation.Options()
        options.userPassword = "reader"
        options.ownerPassword = "owner"
        options.allowPrinting = false
        let outputs = try await fixtures.run(ProtectOperation(), [InputFile(url: url)], options)
        let pdf = try QPDF(url: outputs[0].url, password: "reader")
        #expect(pdf.encryption == QPDF.EncryptionInfo(version: 5, revision: 6, method: "/AESV3"))
        #expect(throws: QPDF.Failure.self) { try QPDF(url: outputs[0].url) }
    }

    @Test("Protecting keeps the rest of the file: rotation, bookmarks, text")
    func keepsDocument() async throws {
        let url = try fixtures.pdf(pages: 2, rotations: [90, 0])
        let merged = try await fixtures.run(MergeOperation(), [InputFile(url: url), InputFile(url: url)], .init())
        var options = ProtectOperation.Options()
        options.userPassword = "pw"
        let outputs = try await fixtures.run(ProtectOperation(), [InputFile(url: merged[0].url)], options)
        let document = try Inspect.document(outputs[0].url, password: "pw")
        #expect((0..<4).map { document.page(at: $0)?.rotation } == [90, 0, 90, 0])
        #expect(document.outlineRoot?.numberOfChildren == 2)
        #expect(document.page(at: 3)?.string?.contains("Page 2") == true)
    }

    @Test("An empty password is refused, naming the output")
    func emptyPassword() async throws {
        let url = try fixtures.pdf(pages: 1)
        let error = await #expect(throws: PDFEngineError.self) {
            try await ProtectOperation().run([InputFile(url: url)], options: .init()) { _ in }
        }
        guard case .writeFailed(let target) = error else {
            Issue.record("expected .writeFailed, got \(String(describing: error))")
            return
        }
        #expect(target.lastPathComponent == "localpdf_protect_report.pdf")
    }
}

@Suite("Unlock")
struct UnlockOperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    @Test("With the password, the output is no longer encrypted")
    func unlocks() async throws {
        let url = try fixtures.encryptedPDF(pages: 3, password: "pw")
        let outputs = try await fixtures.run(UnlockOperation(), [InputFile(url: url, password: "pw")], .init())
        #expect(outputs.map(\.suggestedName) == ["localpdf_unlock_secret.pdf"])
        let document = try #require(PDFDocument(url: outputs[0].url))
        #expect(!document.isEncrypted)
        #expect(!document.isLocked)
        #expect(try Inspect.texts(outputs[0].url) == ["Page 1", "Page 2", "Page 3"])
    }

    @Test("Permission-only restrictions go without a password")
    func restrictions() async throws {
        let url = try fixtures.restrictedPDF(pages: 1)
        #expect(try #require(PDFDocument(url: url)).allowsCopying == false)
        let outputs = try await fixtures.run(UnlockOperation(), [InputFile(url: url)], .init())
        let document = try #require(PDFDocument(url: outputs[0].url))
        #expect(!document.isEncrypted)
        #expect(document.allowsCopying)
    }

    @Test("Unlocks what Protect made (AES-256), with either password")
    func roundTrip() async throws {
        let url = try fixtures.pdf(pages: 2)
        var options = ProtectOperation.Options()
        options.userPassword = "reader"
        options.ownerPassword = "owner"
        options.allowCopying = false
        let protected = try await fixtures.run(ProtectOperation(), [InputFile(url: url)], options)
        for password in ["reader", "owner"] {
            let outputs = try await fixtures.run(
                UnlockOperation(), [InputFile(url: protected[0].url, password: password)], .init())
            let document = try #require(PDFDocument(url: outputs[0].url))
            #expect(!document.isEncrypted)
            #expect(document.allowsCopying)
            #expect(try Inspect.texts(outputs[0].url) == ["Page 1", "Page 2"])
        }
    }

    @Test("Missing and wrong passwords are told apart")
    func passwords() async throws {
        let url = try fixtures.encryptedPDF(pages: 1, password: "pw")
        await #expect(throws: PDFEngineError.passwordRequired(url)) {
            try await UnlockOperation().run([InputFile(url: url)], options: .init()) { _ in }
        }
        await #expect(throws: PDFEngineError.passwordRequired(url)) {
            try await UnlockOperation().run([InputFile(url: url, password: "")], options: .init()) { _ in }
        }
        await #expect(throws: PDFEngineError.wrongPassword(url)) {
            try await UnlockOperation().run([InputFile(url: url, password: "PW")], options: .init()) { _ in }
        }
    }
}
