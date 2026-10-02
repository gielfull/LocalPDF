import Foundation
import PDFEngine
import Testing
@testable import LocalPDF

@Suite("Protection dropped notice")
struct ProtectionNoticeTests {
    private let pdf = SavedOutput(url: URL(filePath: "/tmp/out.pdf"), byteCount: 1)
    private let png = SavedOutput(url: URL(filePath: "/tmp/page-1.png"), byteCount: 1)

    @Test("Inputs' protection: password beats restrictions beats none")
    func protectionOfFiles() {
        let plain = SourceFile.fixture("a.pdf")
        let restricted = SourceFile.fixture("b.pdf", encrypted: true)
        let locked = SourceFile.fixture("c.pdf", encrypted: true, locked: true)
        var unlocked = locked
        unlocked.isLocked = false
        unlocked.password = "secret"

        #expect(JobRequest.Protection.of([]) == .unprotected)
        #expect(JobRequest.Protection.of([plain]) == .unprotected)
        #expect(JobRequest.Protection.of([plain, restricted]) == .restrictions)
        #expect(JobRequest.Protection.of([restricted, locked]) == .password)
        // Unlocking for the job doesn't make the original any less protected.
        #expect(JobRequest.Protection.of([unlocked]) == .password)
    }

    @Test("A password supplied mid-job marks the request password-protected")
    func supplyingPassword() {
        let url = URL(filePath: "/tmp/a.pdf")
        let request = JobRequest(
            RotateOperation.self, options: .init(), inputs: [InputFile(url: url)], inputByteCount: 1
        )
        #expect(request.inputProtection == .unprotected)
        #expect(request.supplying(password: "pw", for: url).inputProtection == .password)
    }

    @Test("Protected input, a tool that drops protection: say so")
    func shownWhenDropped() {
        let notice = ProtectionNotice(tool: .rotate, protection: .password, inputCount: 1, outputs: [pdf])
        #expect(notice?.message == "The original was password-protected. This copy isn't.")
    }

    @Test("Several outputs and inputs read in the plural")
    func plural() {
        let notice = ProtectionNotice(tool: .split, protection: .password, inputCount: 1, outputs: [pdf, pdf])
        #expect(notice?.message == "The original was password-protected. These copies aren't.")
        let merged = ProtectionNotice(tool: .merge, protection: .password, inputCount: 3, outputs: [pdf])
        #expect(merged?.message == "A file you added was password-protected. This copy isn't.")
    }

    @Test("Permission-only restrictions are named as such")
    func restrictions() {
        let notice = ProtectionNotice(tool: .watermark, protection: .restrictions, inputCount: 1, outputs: [pdf])
        #expect(notice?.message == "The original had permission restrictions. This copy doesn't.")
    }

    @Test("Protect, Compress, Unlock and Repair never show it")
    func exemptTools() {
        // Repair keeps the input's encryption (qpdf rewrites it as-is).
        for tool in [ToolID.protect, .compress, .unlock, .repair] {
            #expect(ProtectionNotice(tool: tool, protection: .password, inputCount: 1, outputs: [pdf]) == nil)
        }
    }

    @Test("Every other tool that writes PDFs shows it")
    func everyOtherTool() {
        let tools: [ToolID] = [.merge, .split, .removePages, .extractPages, .organize, .rotate,
                               .pageNumbers, .watermark, .crop, .ocr]
        for tool in tools {
            #expect(ProtectionNotice(tool: tool, protection: .restrictions, inputCount: 1, outputs: [pdf]) != nil)
        }
    }

    @Test("Nothing to say for unprotected inputs, image outputs, or no outputs")
    func hiddenOtherwise() {
        #expect(ProtectionNotice(tool: .rotate, protection: .unprotected, inputCount: 1, outputs: [pdf]) == nil)
        #expect(ProtectionNotice(tool: .pdfToImages, protection: .password, inputCount: 1, outputs: [png]) == nil)
        #expect(ProtectionNotice(tool: .rotate, protection: .password, inputCount: 1, outputs: []) == nil)
    }
}
