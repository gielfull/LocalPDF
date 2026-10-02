import Foundation
import Observation
import PDFEngine

/// The state of one tool's screen: its input files and the options the inspector edits.
/// One session per tool lives for the app's lifetime, so switching tools keeps your work.
///
/// Options are held as the engine's own `Options` values where the inspector can bind to
/// them directly; tools whose options are enums with payloads (Split, Watermark) keep
/// flat fields here and assemble their `Options` in `makeRequest()`.
@Observable
final class ToolSession {
    let tool: ToolID

    private(set) var files: [SourceFile] = []
    /// A transient note about files that weren't added, shown above the canvas.
    var notice: String?
    /// The most recent job this session submitted, for the busy state of the button.
    private(set) var lastJob: Job?
    /// The page preview sheet that is showing.
    var pagePreview: PagePreviewRequest?
    /// An image file shown in Quick Look (images have no pages to preview).
    var quickLookURL: URL?

    // MARK: Options

    var merge = MergeOperation.Options()
    var splitMode = SplitModeKind.ranges
    var splitEvery = 2
    /// Page-range text for Split (custom ranges), Remove Pages and Extract Pages.
    var rangeText = ""
    var extract = ExtractPagesOperation.Options()
    var pagePlan = PagePlan()
    var compress = CompressOperation.Options()
    var rotate = RotateOperation.Options()
    var pageNumbers = PageNumbersOperation.Options()
    var watermark = WatermarkOperation.Options()
    var watermarkKind = WatermarkKind.text
    var watermarkText = "CONFIDENTIAL"
    var watermarkFontSize = 48.0
    var watermarkColor = RGBAColor.red
    var watermarkImage: URL?
    var watermarkImageScale = 0.4
    var crop = CropOperation.Options()
    var imagesToPDF = ImagesToPDFOperation.Options()
    var pdfToImages = PDFToImagesOperation.Options()
    var protect = ProtectOperation.Options()
    var protectConfirmation = ""
    var ocr = OCROperation.Options()

    @ObservationIgnored private let queue: JobQueue
    @ObservationIgnored private var plannedFile: PlannedFile?

    init(tool: ToolID, queue: JobQueue, preferences: Preferences) {
        self.tool = tool
        self.queue = queue
        compress.level = preferences.defaultCompressionLevel
    }

    var descriptor: ToolDescriptor { ToolCatalog.descriptor(for: tool) }

    /// The single input of a one-file tool.
    var file: SourceFile? { files.first }

    var isRunning: Bool { lastJob?.isRunning == true }

    // MARK: Files

    func add(_ urls: [URL]) async {
        add(await SourceFile.load(urls))
    }

    /// Adds files the tool accepts and explains any it skipped. One-file tools replace
    /// their file instead.
    func add(_ loaded: [SourceFile]) {
        let accepted = loaded.filter { $0.conforms(to: descriptor.acceptedInputs) }
        var notes: [String] = []
        if accepted.count < loaded.count {
            let skipped = loaded.count - accepted.count
            notes.append("\(skipped) \(skipped == 1 ? "file wasn't" : "files weren't") added: \(descriptor.title) takes \(acceptedKindDescription).")
        }
        if descriptor.allowsMultipleInputs {
            files += accepted
        } else if let first = accepted.first {
            if accepted.count > 1 {
                notes.append("\(descriptor.title) works on one file at a time, so it uses \u{201C}\(first.name)\u{201D}.")
            }
            files = [first]
        }
        notice = notes.isEmpty ? nil : notes.joined(separator: " ")
        filesDidChange()
        if let locked = files.first(where: \.needsPassword) {
            requestPassword(for: locked)
        }
    }

    /// Replaces every file, e.g. when a suggestion or "Continue with…" opens this tool.
    func replaceFiles(with loaded: [SourceFile]) {
        files = []
        add(loaded)
    }

    func remove(_ id: SourceFile.ID) {
        files.removeAll { $0.id == id }
        notice = nil
        filesDidChange()
    }

    func removeAll() {
        files = []
        notice = nil
        filesDidChange()
    }

    func moveFiles(_ sources: [SourceFile.ID], before target: SourceFile.ID?) {
        files = Reorder.move(files, sources: sources, before: target)
    }

    /// Asks for `file`'s open password, then swaps in the unlocked file.
    func requestPassword(for file: SourceFile, then continuation: (() -> Void)? = nil) {
        queue.passwordRequest = PasswordRequest(file: file) { [weak self] unlocked in
            guard let self, let index = files.firstIndex(where: { $0.id == unlocked.id }) else { return }
            files[index] = unlocked
            filesDidChange()
            continuation?()
        }
    }

    /// Page-level state follows the single file it describes: a different file (or the
    /// same file after unlocking, when its pages become known) starts a fresh plan.
    private func filesDidChange() {
        let planned = file.map { PlannedFile(id: $0.id, pageCount: $0.pageCount) }
        guard planned != plannedFile else { return }
        plannedFile = planned
        pagePlan = PagePlan(pageCount: planned?.pageCount ?? 0)
        rangeText = ""
    }

    private struct PlannedFile: Equatable {
        let id: SourceFile.ID
        let pageCount: Int
    }

    private var acceptedKindDescription: String {
        descriptor.acceptedInputs.contains(.pdf) ? "PDF files" : "image files"
    }

    // MARK: Previewing

    /// Opens the preview at `page` of the single file, paging through all of its pages.
    func previewPage(_ page: Int) {
        guard let file, file.kind == .pdf, !file.needsPassword, file.pageCount > 0 else { return }
        pagePreview = .allPages(of: file, startingAt: page)
    }

    /// Opens the preview at an Organize page, paging through the plan as arranged:
    /// its order, its rotations, and without the blank pages.
    func previewPlanPage(_ id: PagePlan.Page.ID) {
        guard let file, !file.needsPassword else { return }
        let pages = pagePlan.pages.filter { $0.sourceIndex != nil }
        guard let start = pages.firstIndex(where: { $0.id == id }) else { return }
        let items = pages.compactMap { page in
            page.sourceIndex.map { PagePreviewRequest.Item(sourceIndex: $0, rotation: page.rotation) }
        }
        pagePreview = PagePreviewRequest(file: file, items: items, start: start)
    }

    /// Previews a whole file: its pages for a PDF, Quick Look for an image.
    func preview(_ file: SourceFile) {
        switch file.kind {
        case .pdf where !file.needsPassword && file.pageCount > 0:
            pagePreview = .allPages(of: file, startingAt: 0)
        case .image:
            quickLookURL = file.url
        default:
            break
        }
    }

    // MARK: Running

    var primaryActionTitle: String {
        switch tool {
        case .organize: "Save Organized PDF"
        case .imagesToPDF: "Convert to PDF"
        case .pdfToImages: "Convert to Images"
        case .ocr: "Make Searchable"
        default: descriptor.title
        }
    }

    /// What the primary button says while the job runs, before "…" and the percentage.
    var runningTitle: String {
        switch tool {
        case .merge: "Merging"
        case .split: "Splitting"
        case .removePages: "Removing pages"
        case .extractPages: "Extracting pages"
        case .organize: "Saving"
        case .compress: "Compressing"
        case .rotate: "Rotating"
        case .pageNumbers: "Adding page numbers"
        case .watermark: "Adding watermark"
        case .crop: "Cropping"
        case .imagesToPDF, .pdfToImages: "Converting"
        case .protect: "Protecting"
        case .unlock: "Unlocking"
        case .ocr: "Recognizing text"
        default: "Working"
        }
    }

    func cancel() {
        guard let lastJob, lastJob.isRunning else { return }
        queue.cancel(lastJob)
    }

    func run() {
        if let locked = files.first(where: \.needsPassword) {
            requestPassword(for: locked) { [weak self] in self?.run() }
            return
        }
        guard validationMessage == nil, let request = makeRequest() else { return }
        lastJob = queue.submit(request)
    }
}

