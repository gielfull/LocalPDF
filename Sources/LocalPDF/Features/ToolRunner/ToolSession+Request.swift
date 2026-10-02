import Foundation
import PDFEngine

/// Turning a session's state into a job: what the canvas shows, why the primary action
/// is disabled, and the `JobRequest` with each tool's `Options` assembled.
extension ToolSession {
    /// What the center canvas shows for this tool.
    enum Canvas {
        /// A grid of file cards; draggable when the order matters.
        case files(reorderable: Bool)
        /// The single file's pages, clickable to edit the range text.
        case pageSelection
        /// The Organize page editor.
        case organize
    }

    var canvas: Canvas {
        switch tool {
        case .merge, .imagesToPDF: .files(reorderable: true)
        case .split, .removePages, .extractPages: .pageSelection
        case .organize: .organize
        default: .files(reorderable: false)
        }
    }

    /// Why the primary action can't run yet, or nil when it can.
    var validationMessage: String? {
        guard !files.isEmpty else {
            return descriptor.acceptedInputs.contains(.pdf)
                ? (descriptor.allowsMultipleInputs ? "Add PDF files to get started." : "Add a PDF to get started.")
                : "Add images to get started."
        }
        if let locked = files.first(where: \.needsPassword) {
            return "\u{201C}\(locked.name)\u{201D} needs its password."
        }
        switch tool {
        case .merge where files.count < 2:
            return "Add at least two PDFs to merge."
        case .split:
            return splitMessage
        case .removePages:
            if rangeText.isBlank { return "Choose the pages to remove." }
            if let message = rangeMessage(rangeText) { return message }
            if let file, PageRangeSync.pages(in: rangeText, pageCount: file.pageCount).count >= file.pageCount {
                return "You can't remove every page."
            }
            return nil
        case .extractPages:
            return rangeText.isBlank ? "Choose the pages to extract." : rangeMessage(rangeText)
        case .organize:
            return pagePlan.pages.isEmpty ? "Keep at least one page." : nil
        case .rotate:
            return selectionMessage(rotate.pages)
        case .pageNumbers:
            if pageNumbers.format.isBlank { return "Enter a number format." }
            return selectionMessage(pageNumbers.pages)
        case .watermark:
            switch watermarkKind {
            case .text where watermarkText.isBlank: return "Type the watermark text."
            case .image where watermarkImage == nil: return "Choose a watermark image."
            default: return selectionMessage(watermark.pages)
            }
        case .crop:
            if [crop.top, crop.left, crop.bottom, crop.right].allSatisfy({ $0 <= 0 }) {
                return "Set at least one margin to crop."
            }
            return selectionMessage(crop.pages)
        case .protect:
            if protect.userPassword.isEmpty { return "Enter a password." }
            if protect.userPassword != protectConfirmation { return "The passwords don't match." }
            return nil
        default:
            return nil
        }
    }

    private var splitMessage: String? {
        switch splitMode {
        case .ranges: rangeText.isBlank ? "Type the ranges to split into." : rangeMessage(rangeText)
        case .everyN: splitEvery >= 1 ? nil : "Choose how many pages go in each file."
        case .eachPage: nil
        }
    }

    /// Checks range text against every input (they may differ in length).
    private func rangeMessage(_ text: String) -> String? {
        for file in files {
            do {
                _ = try PageRange(parsing: text, pageCount: file.pageCount)
            } catch {
                return error.localizedDescription
            }
        }
        return nil
    }

    private func selectionMessage(_ selection: PageSelection) -> String? {
        guard let text = selection else { return nil }
        return text.isBlank ? "Type the pages to apply this to." : rangeMessage(text)
    }

    /// The job for the current state, or nil when the tool has no operation yet.
    func makeRequest() -> JobRequest? {
        let inputs = files.map { InputFile(url: $0.url, password: $0.password) }
        let bytes = files.reduce(Int64(0)) { $0 + $1.byteCount }
        let protection = JobRequest.Protection.of(files)

        func request<Operation: PDFOperation>(_ operation: Operation.Type, _ options: Operation.Options) -> JobRequest {
            JobRequest(operation, options: options, inputs: inputs, inputByteCount: bytes, inputProtection: protection)
        }

        switch tool {
        case .merge:
            return request(MergeOperation.self, merge)
        case .split:
            var options = SplitOperation.Options()
            options.mode = switch splitMode {
            case .ranges: .customRanges(rangeText)
            case .everyN: .everyNPages(splitEvery)
            case .eachPage: .eachPage
            }
            return request(SplitOperation.self, options)
        case .removePages:
            var options = RemovePagesOperation.Options()
            options.pages = rangeText
            return request(RemovePagesOperation.self, options)
        case .extractPages:
            var options = extract
            options.pages = rangeText
            return request(ExtractPagesOperation.self, options)
        case .organize:
            var options = OrganizeOperation.Options()
            options.pages = pagePlan.instructions
            return request(OrganizeOperation.self, options)
        case .compress:
            return request(CompressOperation.self, compress)
        case .rotate:
            return request(RotateOperation.self, rotate)
        case .pageNumbers:
            return request(PageNumbersOperation.self, pageNumbers)
        case .watermark:
            return request(WatermarkOperation.self, watermarkOptions)
        case .crop:
            return request(CropOperation.self, crop)
        case .imagesToPDF:
            return request(ImagesToPDFOperation.self, imagesToPDF)
        case .pdfToImages:
            return request(PDFToImagesOperation.self, pdfToImages)
        case .protect:
            return request(ProtectOperation.self, protect)
        case .unlock:
            return request(UnlockOperation.self, UnlockOperation.Options())
        case .repair:
            return request(RepairOperation.self, RepairOperation.Options())
        case .ocr:
            return request(OCROperation.self, ocr)
        default:
            return nil
        }
    }

    /// The watermark options with the content assembled from the flat inspector fields.
    var watermarkOptions: WatermarkOperation.Options {
        var options = watermark
        switch watermarkKind {
        case .text:
            options.content = .text(watermarkText, fontSize: watermarkFontSize, color: watermarkColor)
        case .image:
            if let watermarkImage {
                options.content = .image(watermarkImage, scale: watermarkImageScale)
            }
        }
        return options
    }

    /// For Split: which output file each 0-based page lands in, to label the page grid.
    var splitGroups: [Int: Int] {
        guard let file else { return [:] }
        switch splitMode {
        case .ranges:
            return PageRangeSync.parts(in: rangeText, pageCount: file.pageCount)
        case .everyN:
            let size = max(splitEvery, 1)
            return Dictionary(uniqueKeysWithValues: (0..<file.pageCount).map { ($0, $0 / size) })
        case .eachPage:
            return Dictionary(uniqueKeysWithValues: (0..<file.pageCount).map { ($0, $0) })
        }
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespaces).isEmpty }
}
