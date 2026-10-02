import Foundation
import PDFKit
import Testing
@testable import PDFEngine

@Suite("Rotate")
struct RotateOperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    @Test("Rotates only the selected pages")
    func selectedPages() async throws {
        let url = try fixtures.pdf(pages: 3)
        var options = RotateOperation.Options()
        options.pages = "2"
        let outputs = try await fixtures.run(RotateOperation(), [InputFile(url: url)], options)
        #expect(outputs.map(\.suggestedName) == ["localpdf_rotate_report.pdf"])
        #expect(try Inspect.rotations(outputs[0].url) == [0, 90, 0])
        #expect(try Inspect.texts(outputs[0].url) == ["Page 1", "Page 2", "Page 3"])
    }

    @Test("Adds to the existing rotation, modulo 360", arguments: [
        (270, [0, 270, 90]),
        (-90, [0, 270, 90]),
        (180, [270, 180, 0]),
        (100, [180, 90, 270]), // snaps to 90
    ])
    func addsToExisting(degrees: Int, expected: [Int]) async throws {
        let url = try fixtures.pdf(pages: 3, rotations: [90, 0, 180])
        var options = RotateOperation.Options()
        options.degrees = degrees
        let outputs = try await fixtures.run(RotateOperation(), [InputFile(url: url)], options)
        #expect(try Inspect.rotations(outputs[0].url) == expected)
    }

    @Test("Each input gets its own output, even with the same name")
    func batch() async throws {
        let a = try fixtures.pdf("report", pages: 1)
        let other = fixtures.directory.appending(path: "other", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let b = other.appending(path: "report.pdf")
        try FileManager.default.copyItem(at: a, to: b)
        let outputs = try await fixtures.run(RotateOperation(), [InputFile(url: a), InputFile(url: b)], .init())
        #expect(outputs.map(\.suggestedName) == ["localpdf_rotate_report.pdf", "localpdf_rotate_report 2.pdf"])
        #expect(Set(outputs.map(\.url)).count == 2)
    }

    @Test("Works on a file whose permissions forbid page changes")
    func restricted() async throws {
        let url = try fixtures.restrictedPDF(pages: 2)
        let outputs = try await fixtures.run(RotateOperation(), [InputFile(url: url)], .init())
        #expect(try Inspect.rotations(outputs[0].url) == [90, 90])
    }

    @Test("A locked input needs its password, and the right one")
    func passwords() async throws {
        let url = try fixtures.encryptedPDF(pages: 2, password: "open sesame")
        await #expect(throws: PDFEngineError.passwordRequired(url)) {
            try await RotateOperation().run([InputFile(url: url)], options: .init()) { _ in }
        }
        await #expect(throws: PDFEngineError.wrongPassword(url)) {
            try await RotateOperation().run([InputFile(url: url, password: "nope")], options: .init()) { _ in }
        }
        let outputs = try await fixtures.run(
            RotateOperation(), [InputFile(url: url, password: "open sesame")], .init())
        #expect(try Inspect.rotations(outputs[0].url) == [90, 90])
    }

    @Test("A bad page selection throws")
    func badSelection() async throws {
        let url = try fixtures.pdf(pages: 3)
        var options = RotateOperation.Options()
        options.pages = "0"
        await #expect(throws: PDFEngineError.invalidPageRange("0")) {
            try await RotateOperation().run([InputFile(url: url)], options: options) { _ in }
        }
    }

    @Test("Cancellation stops the job")
    func cancellation() async throws {
        let url = try fixtures.pdf(pages: 3)
        let task = Task {
            while !Task.isCancelled { await Task.yield() }
            return try await RotateOperation().run([InputFile(url: url)], options: .init()) { _ in }
        }
        task.cancel()
        await #expect(throws: PDFEngineError.cancelled) { try await task.value }
    }
}

@Suite("Crop")
struct CropOperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    @Test("Insets the existing crop box and keeps the media box")
    func unrotated() async throws {
        let url = try fixtures.pdf(pages: 2, cropBox: CGRect(x: 36, y: 36, width: 540, height: 720))
        var options = CropOperation.Options()
        (options.top, options.left, options.bottom, options.right) = (10, 20, 30, 40)
        options.pages = "1"
        let outputs = try await fixtures.run(CropOperation(), [InputFile(url: url)], options)
        #expect(outputs.map(\.suggestedName) == ["localpdf_crop_report.pdf"])
        #expect(try Inspect.box(.cropBox, of: outputs[0].url, page: 0) == CGRect(x: 56, y: 66, width: 480, height: 680))
        #expect(try Inspect.box(.mediaBox, of: outputs[0].url, page: 0) == CGRect(x: 0, y: 0, width: 612, height: 792))
        // Page 2 wasn't selected.
        #expect(try Inspect.box(.cropBox, of: outputs[0].url, page: 1) == CGRect(x: 36, y: 36, width: 540, height: 720))
    }

    @Test("Insets are as the reader sees the page, whatever its rotation")
    func rotated() async throws {
        // Shown at 90°, the 612 × 792 page reads 792 wide by 612 tall; its reader-top edge
        // is the page's left edge (x = 0) and its reader-left edge the page's bottom (y = 0).
        let url = try fixtures.pdf(pages: 1, rotations: [90])
        var options = CropOperation.Options()
        (options.top, options.left, options.bottom, options.right) = (10, 20, 30, 40)
        let outputs = try await fixtures.run(CropOperation(), [InputFile(url: url)], options)
        #expect(try Inspect.box(.cropBox, of: outputs[0].url, page: 0) == CGRect(x: 10, y: 20, width: 572, height: 732))
        #expect(try Inspect.rotations(outputs[0].url) == [90])
    }

    @Test("Negative insets count as zero")
    func negative() async throws {
        let url = try fixtures.pdf(pages: 1)
        var options = CropOperation.Options()
        options.top = -50
        options.left = 12
        let outputs = try await fixtures.run(CropOperation(), [InputFile(url: url)], options)
        #expect(try Inspect.box(.cropBox, of: outputs[0].url, page: 0) == CGRect(x: 12, y: 0, width: 600, height: 792))
    }

    @Test("Insets that leave nothing name the page")
    func empty() async throws {
        let url = try fixtures.pdf(pages: 2, sizes: [CGSize(width: 612, height: 792), CGSize(width: 200, height: 200)])
        var options = CropOperation.Options()
        (options.left, options.right) = (150, 150)
        await #expect(throws: PDFEngineError.invalidPageRange("2")) {
            try await CropOperation().run([InputFile(url: url)], options: options) { _ in }
        }
    }
}

@Suite("Page Numbers")
struct PageNumbersOperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    @Test("Numbers the selected pages from the start number, keeping the original text")
    func numbers() async throws {
        let url = try fixtures.pdf(pages: 3)
        var options = PageNumbersOperation.Options()
        options.format = "Folio {n} of {total}"
        options.startNumber = 5
        options.pages = "2-"
        let outputs = try await fixtures.run(PageNumbersOperation(), [InputFile(url: url)], options)
        #expect(outputs.map(\.suggestedName) == ["localpdf_page-numbers_report.pdf"])
        let texts = try Inspect.texts(outputs[0].url)
        #expect(texts.count == 3)
        #expect(!texts[0].contains("Folio"))
        #expect(texts[1].contains("Folio 5 of 6"))
        #expect(texts[2].contains("Folio 6 of 6"))
        for (index, text) in texts.enumerated() {
            #expect(text.contains("Page \(index + 1)"), "original text no longer extractable")
        }
    }

    @Test("Keeps page sizes, crop boxes and rotations")
    func geometry() async throws {
        let url = try fixtures.pdf(pages: 2, sizes: [CGSize(width: 612, height: 792), CGSize(width: 842, height: 595)],
                                   rotations: [0, 270], cropBox: CGRect(x: 10, y: 10, width: 500, height: 500))
        let outputs = try await fixtures.run(PageNumbersOperation(), [InputFile(url: url)], .init())
        #expect(try Inspect.box(.mediaBox, of: outputs[0].url, page: 1) == CGRect(x: 0, y: 0, width: 842, height: 595))
        #expect(try Inspect.box(.cropBox, of: outputs[0].url, page: 1) == CGRect(x: 10, y: 10, width: 500, height: 500))
        #expect(try Inspect.rotations(outputs[0].url) == [0, 270])
    }

    @Test("The stamp sits where the reader expects, on upright and rotated pages",
          arguments: [0, 90, 180, 270])
    func placement(rotation: Int) async throws {
        let url = try fixtures.pdf(pages: 1, rotations: [rotation])
        var options = PageNumbersOperation.Options()
        options.format = "Stamp{n}"
        options.position = .bottomRight
        let outputs = try await fixtures.run(PageNumbersOperation(), [InputFile(url: url)], options)
        let page = try #require(try Inspect.document(outputs[0].url).page(at: 0))
        let position = try Inspect.relativeReaderPosition(of: "Stamp1", on: page)
        #expect(position.x > 0.8, "stamp should be at the reader's right, is at \(position)")
        #expect(position.y < 0.15, "stamp should be at the reader's bottom, is at \(position)")
    }

    @Test("Bookmarks survive the stamp pipeline")
    func outline() async throws {
        let url = try fixtures.pdf(pages: 2)
        try fixtures.modify(url) { document in
            let root = PDFOutline()
            document.outlineRoot = root
            let entry = PDFOutline()
            entry.label = "Second"
            entry.destination = PDFDestination(page: try #require(document.page(at: 1)), at: .zero)
            root.insertChild(entry, at: 0)
        }
        let outputs = try await fixtures.run(PageNumbersOperation(), [InputFile(url: url)], .init())
        let document = try Inspect.document(outputs[0].url)
        let entry = try #require(document.outlineRoot?.child(at: 0))
        #expect(entry.label == "Second")
        #expect(document.index(for: try #require(entry.destination?.page)) == 1)
    }
}

@Suite("Watermark")
struct WatermarkOperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    private func textOptions(_ text: String = "SECRETMARK") -> WatermarkOperation.Options {
        var options = WatermarkOperation.Options()
        options.content = .text(text, fontSize: 36, color: .red)
        return options
    }

    @Test("Text over the content, original text still extractable",
          arguments: [WatermarkOperation.Layer.overContent, .underContent])
    func text(layer: WatermarkOperation.Layer) async throws {
        let url = try fixtures.pdf(pages: 2)
        var options = textOptions()
        options.layer = layer
        let outputs = try await fixtures.run(WatermarkOperation(), [InputFile(url: url)], options)
        #expect(outputs.map(\.suggestedName) == ["localpdf_watermark_report.pdf"])
        let texts = try Inspect.texts(outputs[0].url)
        #expect(texts.count == 2)
        for (index, text) in texts.enumerated() {
            #expect(text.contains("SECRETMARK"))
            #expect(text.contains("Page \(index + 1)"))
        }
    }

    @Test("Only the selected pages")
    func selection() async throws {
        let url = try fixtures.pdf(pages: 3)
        var options = textOptions()
        options.pages = "1, 3"
        let outputs = try await fixtures.run(WatermarkOperation(), [InputFile(url: url)], options)
        let texts = try Inspect.texts(outputs[0].url)
        #expect(texts.map { $0.contains("SECRETMARK") } == [true, false, true])
    }

    @Test("Tiled repeats the stamp across the page")
    func tiled() async throws {
        let url = try fixtures.pdf(pages: 1)
        var options = textOptions("TILE")
        options.tiled = true
        let outputs = try await fixtures.run(WatermarkOperation(), [InputFile(url: url)], options)
        let text = try #require(try Inspect.texts(outputs[0].url).first)
        #expect(text.components(separatedBy: "TILE").count - 1 >= 4)
    }

    @Test("An image watermark lands on every page as an image")
    func image() async throws {
        let url = try fixtures.pdf(pages: 2)
        let logo = try fixtures.image("logo", width: 120, height: 60, type: .png)
        var options = WatermarkOperation.Options()
        options.content = .image(logo, scale: 0.3)
        let outputs = try await fixtures.run(WatermarkOperation(), [InputFile(url: url)], options)
        let document = try #require(CGPDFDocument(outputs[0].url as CFURL))
        var seen = Set<CGPDFStreamRef>()
        for pageNumber in 1...2 {
            let page = try #require(document.page(at: pageNumber))
            seen.removeAll()
            #expect(!PDFImageXObjects.images(on: page, seen: &seen).isEmpty, "page \(pageNumber)")
        }
        #expect(try Inspect.texts(outputs[0].url) == ["Page 1", "Page 2"])
    }

    @Test("An unreadable image is reported")
    func badImage() async throws {
        let url = try fixtures.pdf(pages: 1)
        let notImage = try fixtures.textFile()
        var options = WatermarkOperation.Options()
        options.content = .image(notImage, scale: 0.3)
        await #expect(throws: PDFEngineError.unsupportedInput(notImage)) {
            try await WatermarkOperation().run([InputFile(url: url)], options: options) { _ in }
        }
    }
}
