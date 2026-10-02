import CoreGraphics
import CoreText
import Foundation
import ImageIO
import PDFKit
import Testing
import UniformTypeIdentifiers
@testable import PDFEngine

/// Builds fixture files on the fly in a private temp folder (no binary fixtures in git),
/// runs operations, and removes everything, outputs included, when it goes away.
///
/// Each test creates its own instance, so parallel tests never share files.
final class Fixtures {
    let directory: URL
    private var outputDirectories: Set<URL> = []

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "PDFEngineTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
        for url in outputDirectories { try? FileManager.default.removeItem(at: url) }
    }

    // MARK: - Running operations

    /// Runs `operation`, checks the progress contract (starts at 0, never goes backwards,
    /// ends at exactly 1) and that outputs live outside the inputs' folder, then returns them.
    func run<Operation: PDFOperation>(
        _ operation: Operation, _ inputs: [InputFile], _ options: Operation.Options,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> [OutputFile] {
        let log = ProgressLog()
        let outputs = try await operation.run(inputs, options: options) { log.append($0) }
        for output in outputs {
            outputDirectories.insert(output.url.deletingLastPathComponent())
            #expect(FileManager.default.fileExists(atPath: output.url.path), sourceLocation: sourceLocation)
            #expect(!output.url.path.hasPrefix(directory.path), "wrote next to the inputs",
                    sourceLocation: sourceLocation)
        }
        let values = log.values
        #expect(values.first == 0, sourceLocation: sourceLocation)
        #expect(values.last == 1, sourceLocation: sourceLocation)
        #expect(values == values.sorted(), "progress went backwards", sourceLocation: sourceLocation)
        #expect(values.filter { $0 == 1 }.count == 1, sourceLocation: sourceLocation)
        return outputs
    }

    // MARK: - PDFs

    /// A PDF whose page k (1-based) shows the text "\(label) k" near its top-left corner.
    /// `sizes` and `rotations` are per page and cycle when shorter than `pages`.
    @discardableResult
    func pdf(
        _ name: String = "report", pages: Int, label: String = "Page",
        sizes: [CGSize] = [CGSize(width: 612, height: 792)], rotations: [Int] = [0],
        cropBox: CGRect? = nil
    ) throws -> URL {
        let url = directory.appending(path: "\(name).pdf")
        var defaultBox = CGRect(origin: .zero, size: sizes[0])
        let context = try #require(CGContext(url as CFURL, mediaBox: &defaultBox, nil))
        for page in 1...pages {
            let size = sizes[(page - 1) % sizes.count]
            var info: [CFString: Any] = [kCGPDFContextMediaBox: CGRect(origin: .zero, size: size).pdfBoxData]
            if let cropBox { info[kCGPDFContextCropBox] = cropBox.pdfBoxData }
            context.beginPDFPage(info as CFDictionary)
            drawText("\(label) \(page)", at: CGPoint(x: 72, y: size.height - 100), size: 24, in: context)
            context.endPDFPage()
        }
        context.closePDF()

        if rotations.contains(where: { $0 != 0 }) {
            try modify(url) { document in
                for index in 0..<pages {
                    document.page(at: index)?.rotation = rotations[index % rotations.count]
                }
            }
        }
        return url
    }

    /// Edits the PDF at `url` with PDFKit and saves it in place.
    ///
    /// The pages are moved into a fresh `PDFDocument` first: PDFKit doesn't save a new
    /// outline (and writes broken link targets) for a document opened from a file. And it
    /// reads lazily, so it can't safely write over its source: save aside, then swap in.
    func modify(_ url: URL, _ change: (PDFDocument) throws -> Void) throws {
        let edited = directory.appending(path: "edited-\(UUID().uuidString).pdf")
        do {
            let source = try #require(PDFDocument(url: url))
            let document = PDFDocument()
            for index in 0..<source.pageCount {
                let page = try #require(source.page(at: index)?.copy() as? PDFPage)
                document.insert(page, at: index)
            }
            try change(document)
            try #require(document.write(to: edited))
        }
        _ = try FileManager.default.replaceItemAt(url, withItemAt: edited)
    }

    /// A PDF with an open password (and a different owner password).
    func encryptedPDF(_ name: String = "secret", pages: Int, password: String) throws -> URL {
        try encrypt(try pdf("\(name)-plain", pages: pages), as: name,
                    userPassword: password, ownerPassword: "\(password)-owner")
    }

    /// A PDF that opens without a password but forbids copying, printing and editing.
    func restrictedPDF(_ name: String = "restricted", pages: Int) throws -> URL {
        try encrypt(try pdf("\(name)-plain", pages: pages), as: name,
                    userPassword: nil, ownerPassword: "owner", permissions: 0)
    }

    /// An encrypted copy of `plain`, saved as "\(name).pdf".
    func encrypt(_ plain: URL, as name: String, userPassword: String?, ownerPassword: String,
                 permissions: UInt? = nil) throws -> URL {
        let url = directory.appending(path: "\(name).pdf")
        let document = try #require(PDFDocument(url: plain))
        var options: [PDFDocumentWriteOption: Any] = [.ownerPasswordOption: ownerPassword]
        if let userPassword { options[.userPasswordOption] = userPassword }
        if let permissions { options[.accessPermissionsOption] = NSNumber(value: permissions) }
        try #require(document.write(to: url, withOptions: options))
        return url
    }

    /// A text-free PDF with one image per page, like a scan. `jpeg` embeds JPEG bytes
    /// (DCTDecode); otherwise the pixels go in as a Flate-compressed RGB image.
    func imagePDF(_ name: String = "scan", pages: Int, imageSize: CGSize, jpeg: Bool,
                  quality: Double = 0.95) throws -> URL {
        let url = directory.appending(path: "\(name).pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try #require(CGContext(url as CFURL, mediaBox: &box, nil))
        for page in 1...pages {
            var image = try noiseImage(size: imageSize, seed: page)
            if jpeg {
                let data = try #require(ImageEncoding.data(image, type: .jpeg, quality: quality))
                let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
                image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            }
            context.beginPDFPage(nil)
            context.draw(image, in: box)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }

    /// One page with a JPEG image and a Flate image of the given pixel sizes, plus text.
    func mixedImagePDF(_ name: String = "mixed", jpegSize: CGSize, flateSize: CGSize) throws -> URL {
        let url = directory.appending(path: "\(name).pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try #require(CGContext(url as CFURL, mediaBox: &box, nil))
        let jpegData = try #require(ImageEncoding.data(try noiseImage(size: jpegSize, seed: 1),
                                                       type: .jpeg, quality: 0.9))
        let source = try #require(CGImageSourceCreateWithData(jpegData as CFData, nil))
        let jpegImage = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        context.beginPDFPage(nil)
        context.draw(jpegImage, in: CGRect(x: 36, y: 400, width: 300, height: 300))
        context.draw(try noiseImage(size: flateSize, seed: 2), in: CGRect(x: 36, y: 36, width: 300, height: 200))
        drawText("Images inside", at: CGPoint(x: 360, y: 700), size: 18, in: context)
        context.endPDFPage()
        context.closePDF()
        return url
    }

    // MARK: - Images

    /// An image file whose stored pixels are red on the left half and blue on the right,
    /// with a green square in the top-left corner, tagged with EXIF `orientation`.
    func image(_ name: String, width: Int, height: Int, type: UTType = .jpeg,
               orientation: Int = 1) throws -> URL {
        let url = directory.appending(path: "\(name).\(type.preferredFilenameExtension ?? "img")")
        let context = try #require(ImageEncoding.whiteCanvas(width: width, height: height))
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        let side = min(width, height) / 4
        context.setFillColor(CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: height - side, width: side, height: side)) // y-up: the top rows
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(
            url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [
            kCGImagePropertyOrientation: orientation,
            kCGImageDestinationLossyCompressionQuality: 0.9,
        ] as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))
        return url
    }

    /// A plain text file, for "not a PDF / not an image" errors.
    func textFile(_ name: String = "notes.txt") throws -> URL {
        let url = directory.appending(path: name)
        try Data("not a pdf".utf8).write(to: url)
        return url
    }

    // MARK: - Drawing

    func drawText(_ string: String, at point: CGPoint, size: CGFloat, in context: CGContext) {
        let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let attributed = NSAttributedString(string: string, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
        ])
        context.textMatrix = .identity
        context.textPosition = point
        CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
    }

    /// Deterministic colorful noise: compresses poorly, like a photo or a scan.
    func noiseImage(size: CGSize, seed: Int) throws -> CGImage {
        let width = Int(size.width)
        let height = Int(size.height)
        var generator = SplitMix64(seed: UInt64(seed))
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for row in 0..<height {
            for column in 0..<width {
                let offset = (row * width + column) * 4
                // Smooth gradient plus noise, so JPEG at different qualities differs in size.
                let noise = generator.next()
                pixels[offset] = UInt8((column * 255 / max(width, 1) + Int(noise & 0x3F)) & 0xFF)
                pixels[offset + 1] = UInt8((row * 255 / max(height, 1) + Int((noise >> 8) & 0x3F)) & 0xFF)
                pixels[offset + 2] = UInt8(((column + row) & 0xFF) ^ Int((noise >> 16) & 0x1F))
            }
        }
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        return try #require(CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
    }
}
