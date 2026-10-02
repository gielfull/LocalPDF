import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import PDFEngine

@Suite("OCR")
struct OCROperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    /// Key tokens of `Fixtures.scanLines`; checked case-insensitively, so a slightly
    /// different reading of punctuation or case doesn't fail the test.
    static let tokens = ["localpdf", "ocr", "test", "2026", "quick", "brown", "fox", "lazy", "dog"]

    @Test("Makes a scanned page searchable without changing its geometry")
    func searchable() async throws {
        let url = try fixtures.scannedPDF(pages: 2)
        #expect(try Inspect.texts(url) == ["", ""])

        let outputs = try await fixtures.run(OCROperation(), [InputFile(url: url)], .init())
        #expect(outputs.map(\.suggestedName) == ["localpdf_ocr_scan.pdf"])
        let texts = try Inspect.texts(outputs[0].url)
        #expect(texts.count == 2)
        for text in texts {
            for token in Self.tokens {
                #expect(text.localizedCaseInsensitiveContains(token), "“\(token)” missing from “\(text)”")
            }
        }
        for page in 0..<2 {
            for box in [CGPDFBox.mediaBox, .cropBox] {
                #expect(try Inspect.box(box, of: outputs[0].url, page: page) == Inspect.box(box, of: url, page: page))
            }
        }
        #expect(try Inspect.rotations(outputs[0].url) == [0, 0])
    }

    @Test("Selecting a word highlights the scanned word")
    func alignment() async throws {
        let url = try fixtures.scannedPDF()
        let outputs = try await fixtures.run(OCROperation(), [InputFile(url: url)], .init())
        let document = try Inspect.document(outputs[0].url)
        let page = try #require(document.page(at: 0))
        for word in ["LocalPDF", "2026", "brown", "lazy"] {
            try Self.expectAligned(word, on: page)
        }
    }

    @Test("The text layer is invisible: the page renders exactly as before")
    func invisible() async throws {
        let url = try fixtures.scannedPDF()
        let outputs = try await fixtures.run(OCROperation(), [InputFile(url: url)], .init())
        let before = try Self.render(url)
        let after = try Self.render(outputs[0].url)
        #expect(before.count(where: { $0 < 128 }) > 500, "the scan didn't render")
        #expect(before.count == after.count)
        let differing = zip(before, after).count { abs(Int($0) - Int($1)) > 8 }
        #expect(differing == 0, "\(differing) pixels changed")
    }

    @Test("A page rotated 90° is read upright and its layer lines up", arguments: [90, 270])
    func rotated(rotation: Int) async throws {
        let url = try fixtures.scannedPDF(rotation: rotation)
        #expect(try Inspect.rotations(url) == [rotation])
        let outputs = try await fixtures.run(OCROperation(), [InputFile(url: url)], .init())
        #expect(try Inspect.rotations(outputs[0].url) == [rotation])
        #expect(try Inspect.box(.mediaBox, of: outputs[0].url, page: 0) == Inspect.box(.mediaBox, of: url, page: 0))
        let text = try #require(try Inspect.texts(outputs[0].url).first)
        for token in Self.tokens {
            #expect(text.localizedCaseInsensitiveContains(token), "“\(token)” missing from “\(text)”")
        }
        let document = try Inspect.document(outputs[0].url)
        let page = try #require(document.page(at: 0))
        try Self.expectAligned("LocalPDF", on: page)
        try Self.expectAligned("brown", on: page)
    }

    @Test("Pages that already have text are left untouched")
    func skipsPagesWithText() async throws {
        let url = try fixtures.scannedPDF(pages: 2, textPages: [0])
        let original = try Inspect.texts(url)
        #expect(original[0].localizedCaseInsensitiveContains("LocalPDF OCR test 2026"))
        #expect(original[1].isEmpty)

        let outputs = try await fixtures.run(OCROperation(), [InputFile(url: url)], .init())
        let texts = try Inspect.texts(outputs[0].url)
        #expect(texts[0] == original[0])
        #expect(texts[1].localizedCaseInsensitiveContains("brown"))
        // PDFKit normalizes every content stream it writes, so compare with its plain copy.
        let copy = try plainCopy(of: url)
        #expect(try Self.contents(of: outputs[0].url, page: 0) == Self.contents(of: copy, page: 0))
        #expect(try Self.contents(of: outputs[0].url, page: 1) != Self.contents(of: copy, page: 1))
    }

    @Test("With skipping off, a page with text gets a layer too")
    func ocrEveryPage() async throws {
        let url = try fixtures.scannedPDF(pages: 1, textPages: [0])
        var options = OCROperation.Options()
        options.skipPagesWithText = false
        let outputs = try await fixtures.run(OCROperation(), [InputFile(url: url)], options)
        let copy = try plainCopy(of: url)
        #expect(try Self.contents(of: outputs[0].url, page: 0) != Self.contents(of: copy, page: 0))
        let text = try #require(try Inspect.texts(outputs[0].url).first)
        #expect(text.components(separatedBy: "2026").count - 1 == 2, "expected the text twice: \(text)")
    }

    @Test("A blank page gets no layer and doesn't fail")
    func blankPage() async throws {
        let url = try fixtures.scannedPDF(lines: [])
        let outputs = try await fixtures.run(OCROperation(), [InputFile(url: url)], .init())
        #expect(try Inspect.texts(outputs[0].url) == [""])
    }

    @Test("Fast recognition and an explicit language also find the text")
    func fastAndLanguages() async throws {
        let url = try fixtures.scannedPDF()
        var options = OCROperation.Options()
        options.accuracy = .fast
        options.languages = ["en-US", "not-a-language"]
        let outputs = try await fixtures.run(OCROperation(), [InputFile(url: url)], options)
        let text = try #require(try Inspect.texts(outputs[0].url).first)
        for token in ["localpdf", "2026", "brown", "fox"] {
            #expect(text.localizedCaseInsensitiveContains(token), "“\(token)” missing from “\(text)”")
        }
    }

    @Test("Each input gets its own output")
    func batch() async throws {
        let a = try fixtures.scannedPDF("a")
        let b = try fixtures.scannedPDF("b")
        let outputs = try await fixtures.run(OCROperation(), [InputFile(url: a), InputFile(url: b)], .init())
        #expect(outputs.map(\.suggestedName) == ["localpdf_ocr_a.pdf", "localpdf_ocr_b.pdf"])
        for output in outputs {
            #expect(try Inspect.texts(output.url)[0].localizedCaseInsensitiveContains("2026"))
        }
    }

    @Test("A locked input needs its password")
    func password() async throws {
        let scan = try fixtures.scannedPDF("plain")
        let url = try fixtures.encrypt(scan, as: "locked", userPassword: "pw", ownerPassword: "owner")
        await #expect(throws: PDFEngineError.passwordRequired(url)) {
            try await OCROperation().run([InputFile(url: url)], options: .init()) { _ in }
        }
        let outputs = try await fixtures.run(OCROperation(), [InputFile(url: url, password: "pw")], .init())
        #expect(try Inspect.texts(outputs[0].url)[0].localizedCaseInsensitiveContains("2026"))
    }

    @Test("Cancellation stops the job")
    func cancellation() async throws {
        let url = try fixtures.scannedPDF(pages: 3)
        let task = Task {
            while !Task.isCancelled { await Task.yield() }
            return try await OCROperation().run([InputFile(url: url)], options: .init()) { _ in }
        }
        task.cancel()
        await #expect(throws: PDFEngineError.cancelled) { try await task.value }
    }

    @Test("Cancelling mid-job stops before the next page")
    func cancellationMidJob() async throws {
        let url = try fixtures.scannedPDF(pages: 6)
        let started = AsyncStream.makeStream(of: Void.self)
        let task = Task {
            defer { started.continuation.finish() }
            return try await OCROperation().run([InputFile(url: url)], options: .init()) { value in
                if value > 0 { started.continuation.yield() }
            }
        }
        for await _ in started.stream { break }
        task.cancel()
        await #expect(throws: PDFEngineError.cancelled) { try await task.value }
    }

    // MARK: - Languages

    @Test("Supported languages come from Vision as BCP-47 tags")
    func supportedLanguages() {
        let accurate = OCROperation.supportedLanguages()
        #expect(accurate.contains("en-US"))
        #expect(accurate.contains("zh-Hans"))
        #expect(accurate.contains("ja-JP"))
        #expect(Set(accurate).count == accurate.count)
        let fast = OCROperation.supportedLanguages(for: .fast)
        #expect(!fast.isEmpty)
        #expect(Set(fast).isSubset(of: Set(accurate)))
    }

    @Test("Language tags resolve to Vision's languages", arguments: [
        ("en-US", "en-US"), ("en", "en-US"), ("EN-us", "en-US"), ("pt-PT", "pt-BR"),
        ("zh-Hant", "zh-Hant"), ("zh-Hans", "zh-Hans"), ("ja", "ja-JP"),
    ])
    func resolve(tag: String, expected: String) {
        let resolved = TextRecognizer.resolve([tag], among: TextRecognizer.supported(for: .accurate))
        #expect(resolved.map(TextRecognizer.identifier(for:)) == [expected])
    }

    @Test("Unknown tags are dropped, duplicates collapse")
    func resolveUnknown() {
        let supported = TextRecognizer.supported(for: .accurate)
        #expect(TextRecognizer.resolve(["xx-YY", ""], among: supported).isEmpty)
        #expect(TextRecognizer.resolve(["en", "en-US"], among: supported).count == 1)
    }

    @Test("Fast with a language it doesn't know runs accurate")
    func fastUpgrades() {
        var options = OCROperation.Options()
        options.accuracy = .fast
        #expect(TextRecognizer(options: options).accuracy == .fast)
        options.languages = ["fr-FR"]
        #expect(TextRecognizer(options: options).accuracy == .fast)
        options.languages = ["fr-FR", "ja-JP"]
        #expect(TextRecognizer(options: options).accuracy == .accurate)
    }

    // MARK: - Helpers

    /// `word`'s selection on `page`, in reader space, sits on the word in the scan: centers
    /// within a few points, and the selection inside the word's box grown by a margin.
    static func expectAligned(_ word: String, on page: PDFPage,
                              sourceLocation: SourceLocation = #_sourceLocation) throws {
        let string = try #require(page.string, sourceLocation: sourceLocation)
        let range = (string as NSString).range(of: word, options: .caseInsensitive)
        try #require(range.location != NSNotFound, "“\(word)” not in “\(string)”", sourceLocation: sourceLocation)
        let selection = try #require(page.selection(for: range), sourceLocation: sourceLocation)
        // PDFKit's own page-to-display transform is the oracle, independent of the engine's.
        let found = selection.bounds(for: page).applying(page.transform(for: .cropBox))
        let expected = try Fixtures.expectedBounds(of: word)
        #expect(abs(found.midX - expected.midX) < 4, "\(word): \(found) vs \(expected)", sourceLocation: sourceLocation)
        #expect(abs(found.midY - expected.midY) < 4, "\(word): \(found) vs \(expected)", sourceLocation: sourceLocation)
        #expect(expected.insetBy(dx: -4, dy: -4).contains(found), "\(word): \(found) vs \(expected)",
                sourceLocation: sourceLocation)
    }

    /// `url` passed through PDFKit unchanged: every page copied into a new document and saved.
    func plainCopy(of url: URL) throws -> URL {
        let copy = fixtures.directory.appending(path: "plain-copy-\(UUID().uuidString).pdf")
        try FileManager.default.copyItem(at: url, to: copy)
        try fixtures.modify(copy) { _ in }
        return copy
    }

    /// Page 1 as a viewer shows it, in 8-bit gray at 72 dpi.
    static func render(_ url: URL) throws -> [UInt8] {
        let document = try Inspect.document(url)
        let page = try #require(document.page(at: 0))
        let size = page.bounds(for: .cropBox).applying(page.transform(for: .cropBox)).size
        let (width, height) = (Int(size.width.rounded()), Int(size.height.rounded()))
        var pixels = [UInt8](repeating: 255, count: width * height)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue))
            page.draw(with: .cropBox, to: context)
        }
        return pixels
    }

    /// The decoded `/Contents` stream of page `index` (0-based), read with CoreGraphics.
    static func contents(of url: URL, page index: Int) throws -> Data {
        let document = try #require(CGPDFDocument(url as CFURL))
        let dictionary = try #require(document.page(at: index + 1)?.dictionary)
        var stream: CGPDFStreamRef?
        try #require(CGPDFDictionaryGetStream(dictionary, "Contents", &stream))
        var format = CGPDFDataFormat.raw
        let contents = try #require(stream)
        return try #require(CGPDFStreamCopyData(contents, &format) as Data?)
    }
}
