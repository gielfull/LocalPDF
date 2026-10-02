import Foundation
import PDFKit
import Testing
import UniformTypeIdentifiers
@testable import PDFEngine

@Suite("Images to PDF")
struct ImagesToPDFOperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    @Test("Merges images into one PDF on A4, oriented per image")
    func mergedA4() async throws {
        let wide = try fixtures.image("wide", width: 400, height: 200)
        let tall = try fixtures.image("tall", width: 200, height: 300, type: .png)
        let outputs = try await fixtures.run(
            ImagesToPDFOperation(), [InputFile(url: wide), InputFile(url: tall)], .init())
        #expect(outputs.map(\.suggestedName) == ["localpdf_images-to-pdf_wide.pdf"])
        let document = try Inspect.document(outputs[0].url)
        #expect(document.pageCount == 2)
        #expect(try Inspect.box(.mediaBox, of: outputs[0].url, page: 0).size == CGSize(width: 841.89, height: 595.28))
        #expect(try Inspect.box(.mediaBox, of: outputs[0].url, page: 1).size == CGSize(width: 595.28, height: 841.89))
    }

    @Test("A single image is named after itself; forced orientation and Letter apply")
    func singleLetterPortrait() async throws {
        let wide = try fixtures.image("photo", width: 400, height: 200)
        var options = ImagesToPDFOperation.Options()
        options.pageSize = .usLetter
        options.orientation = .portrait
        options.margin = .small
        let outputs = try await fixtures.run(ImagesToPDFOperation(), [InputFile(url: wide)], options)
        #expect(outputs.map(\.suggestedName) == ["localpdf_images-to-pdf_photo.pdf"])
        #expect(try Inspect.box(.mediaBox, of: outputs[0].url, page: 0).size == CGSize(width: 612, height: 792))
        // Aspect-fit inside the 20 pt margins and centered: 572 × 286, so the page's top and
        // bottom bands are white while the middle is image.
        #expect(try Inspect.color(at: CGPoint(x: 0.5, y: 0.9), of: outputs[0].url).name == .white)
        #expect(try Inspect.color(at: CGPoint(x: 0.3, y: 0.5), of: outputs[0].url).name == .red)
        #expect(try Inspect.color(at: CGPoint(x: 0.01, y: 0.5), of: outputs[0].url).name == .white)
    }

    @Test("Fit-image pages are the image size plus the margin")
    func fitImage() async throws {
        let wide = try fixtures.image("wide", width: 400, height: 200)
        var options = ImagesToPDFOperation.Options()
        options.pageSize = .fitImage
        options.margin = .large
        let outputs = try await fixtures.run(ImagesToPDFOperation(), [InputFile(url: wide)], options)
        #expect(try Inspect.box(.mediaBox, of: outputs[0].url, page: 0).size == CGSize(width: 480, height: 280))
    }

    @Test("One PDF per image when not merging")
    func separate() async throws {
        let a = try fixtures.image("first", width: 100, height: 100)
        let b = try fixtures.image("second", width: 100, height: 100)
        var options = ImagesToPDFOperation.Options()
        options.mergeIntoOne = false
        let outputs = try await fixtures.run(ImagesToPDFOperation(), [InputFile(url: a), InputFile(url: b)], options)
        #expect(outputs.map(\.suggestedName) == ["localpdf_images-to-pdf_first.pdf", "localpdf_images-to-pdf_second.pdf"])
        #expect(try outputs.map { try Inspect.document($0.url).pageCount } == [1, 1])
    }

    @Test("JPEGs are embedded as JPEG, not re-encoded pixels")
    func jpegPassthrough() async throws {
        let photo = try fixtures.image("photo", width: 1200, height: 900)
        let outputs = try await fixtures.run(ImagesToPDFOperation(), [InputFile(url: photo)], .init())
        let bytes = try Data(contentsOf: outputs[0].url)
        #expect(bytes.range(of: Data("DCTDecode".utf8)) != nil)
        #expect(try Inspect.fileSize(outputs[0].url) < Inspect.fileSize(photo) + 20_000)
    }

    /// EXIF orientation → (corner where the stored top-left ends up, side the stored left half ends up).
    @Test("Honors every EXIF orientation", arguments: [
        (1, CGPoint(x: 0.05, y: 0.95), CGPoint(x: 0.3, y: 0.5)),
        (2, CGPoint(x: 0.95, y: 0.95), CGPoint(x: 0.7, y: 0.5)),
        (3, CGPoint(x: 0.95, y: 0.05), CGPoint(x: 0.7, y: 0.5)),
        (4, CGPoint(x: 0.05, y: 0.05), CGPoint(x: 0.3, y: 0.5)),
        (5, CGPoint(x: 0.05, y: 0.95), CGPoint(x: 0.5, y: 0.7)),
        (6, CGPoint(x: 0.95, y: 0.95), CGPoint(x: 0.5, y: 0.7)),
        (7, CGPoint(x: 0.95, y: 0.05), CGPoint(x: 0.5, y: 0.3)),
        (8, CGPoint(x: 0.05, y: 0.05), CGPoint(x: 0.5, y: 0.3)),
    ])
    func orientation(exif: Int, greenAt corner: CGPoint, redAt side: CGPoint) async throws {
        let photo = try fixtures.image("photo", width: 300, height: 200, orientation: exif)
        var options = ImagesToPDFOperation.Options()
        options.pageSize = .fitImage
        let outputs = try await fixtures.run(ImagesToPDFOperation(), [InputFile(url: photo)], options)
        let expectedSize = exif >= 5 ? CGSize(width: 200, height: 300) : CGSize(width: 300, height: 200)
        #expect(try Inspect.box(.mediaBox, of: outputs[0].url, page: 0).size == expectedSize)
        #expect(try Inspect.color(at: corner, of: outputs[0].url).name == .green)
        #expect(try Inspect.color(at: side, of: outputs[0].url).name == .red)
    }

    @Test("A file that isn't an image is rejected")
    func notAnImage() async throws {
        let text = try fixtures.textFile()
        await #expect(throws: PDFEngineError.unsupportedInput(text)) {
            try await ImagesToPDFOperation().run([InputFile(url: text)], options: .init()) { _ in }
        }
    }
}

@Suite("PDF to Images")
struct PDFToImagesOperationTests {
    let fixtures: Fixtures
    init() throws { fixtures = try Fixtures() }

    @Test("Renders each page at the requested resolution")
    func render() async throws {
        let url = try fixtures.pdf(pages: 2)
        var options = PDFToImagesOperation.Options()
        options.dpi = 144
        let outputs = try await fixtures.run(PDFToImagesOperation(), [InputFile(url: url)], options)
        #expect(outputs.map(\.suggestedName) == ["localpdf_pdf-to-images_report_page-001.jpg", "localpdf_pdf-to-images_report_page-002.jpg"])
        for output in outputs {
            #expect(try Inspect.pixelSize(output.url) == CGSize(width: 1224, height: 1584))
            #expect(UTType(filenameExtension: output.url.pathExtension) == .jpeg)
        }
    }

    @Test("Rotated pages render as displayed, in each format", arguments: PDFToImagesOperation.Format.allCases)
    func formats(format: PDFToImagesOperation.Format) async throws {
        let url = try fixtures.pdf(pages: 1, rotations: [90])
        var options = PDFToImagesOperation.Options()
        options.format = format
        options.dpi = 72
        let outputs = try await fixtures.run(PDFToImagesOperation(), [InputFile(url: url)], options)
        #expect(try Inspect.pixelSize(outputs[0].url) == CGSize(width: 792, height: 612))
        let source = try #require(CGImageSourceCreateWithURL(outputs[0].url as CFURL, nil))
        let expected: UTType = switch format {
        case .jpeg: .jpeg
        case .png: .png
        case .heic: .heic
        }
        #expect(CGImageSourceGetType(source) as String? == expected.identifier)
    }

    @Test("Resolution is clamped to 72...600")
    func clamped() async throws {
        let url = try fixtures.pdf(pages: 1, sizes: [CGSize(width: 100, height: 50)])
        var options = PDFToImagesOperation.Options()
        options.dpi = 5
        var outputs = try await fixtures.run(PDFToImagesOperation(), [InputFile(url: url)], options)
        #expect(try Inspect.pixelSize(outputs[0].url) == CGSize(width: 100, height: 50))
        options.dpi = 10_000
        outputs = try await fixtures.run(PDFToImagesOperation(), [InputFile(url: url)], options)
        #expect(try Inspect.pixelSize(outputs[0].url) == CGSize(width: 833, height: 417))
    }

    @Test("Extracts embedded images at their stored size; JPEGs byte-for-byte")
    func extract() async throws {
        let url = try fixtures.mixedImagePDF(jpegSize: CGSize(width: 640, height: 480),
                                             flateSize: CGSize(width: 300, height: 200))
        var options = PDFToImagesOperation.Options()
        options.mode = .extractImages
        let outputs = try await fixtures.run(PDFToImagesOperation(), [InputFile(url: url)], options)
        #expect(outputs.count == 2)
        #expect(Set(try outputs.map { try Inspect.pixelSize($0.url) })
                == [CGSize(width: 640, height: 480), CGSize(width: 300, height: 200)])
        #expect(outputs.allSatisfy { $0.suggestedName.hasPrefix("localpdf_pdf-to-images_mixed_image-0") })
        for output in outputs {
            let bytes = try Data(contentsOf: output.url)
            #expect(bytes.prefix(2) == Data([0xFF, 0xD8]), "\(output.suggestedName) isn't a JPEG")
        }
    }

    @Test("Extracted images can be converted to PNG")
    func extractAsPNG() async throws {
        let url = try fixtures.mixedImagePDF(jpegSize: CGSize(width: 64, height: 48),
                                             flateSize: CGSize(width: 30, height: 20))
        var options = PDFToImagesOperation.Options()
        options.mode = .extractImages
        options.format = .png
        let outputs = try await fixtures.run(PDFToImagesOperation(), [InputFile(url: url)], options)
        #expect(outputs.count == 2)
        #expect(outputs.allSatisfy { $0.url.pathExtension == "png" })
        #expect(Set(try outputs.map { try Inspect.pixelSize($0.url) })
                == [CGSize(width: 64, height: 48), CGSize(width: 30, height: 20)])
    }

    @Test("A PDF without images has nothing to extract")
    func nothingToExtract() async throws {
        let url = try fixtures.pdf(pages: 2)
        var options = PDFToImagesOperation.Options()
        options.mode = .extractImages
        await #expect(throws: PDFEngineError.unsupportedInput(url)) {
            try await PDFToImagesOperation().run([InputFile(url: url)], options: options) { _ in }
        }
    }
}
