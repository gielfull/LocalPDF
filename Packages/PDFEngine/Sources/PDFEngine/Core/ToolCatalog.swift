import UniformTypeIdentifiers

/// The single source of truth for which tools exist and how the UI presents them.
///
/// Descriptors are built from an exhaustive `switch` over `ToolID`, so adding a case
/// without a descriptor is a compile error rather than a runtime gap. Implementers
/// add their tool to `implemented` (below) when it ships.
public enum ToolCatalog {
    /// Every `ToolID`, in catalog (sidebar) order.
    public static let all: [ToolDescriptor] = ToolID.allCases.map(make)

    private static let byID: [ToolID: ToolDescriptor] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// The descriptor for `id`. Total: every `ToolID` has exactly one.
    public static func descriptor(for id: ToolID) -> ToolDescriptor {
        // Force-unwrap is safe: `byID` is built from `ToolID.allCases`.
        byID[id]!
    }

    /// The tools in `category`, in catalog order.
    public static func tools(in category: ToolCategory) -> [ToolDescriptor] {
        all.filter { $0.category == category }
    }

    // MARK: - Definitions

    // One long switch on purpose: the whole catalog reads top to bottom in one place.
    private static func make(_ id: ToolID) -> ToolDescriptor {
        switch id {
        // Organize
        case .merge:
            d(id, .organize, "Merge PDF",
              "Combine PDFs in the order you want into one file.",
              "rectangle.stack.badge.plus", pdf, multiple: true)
        case .split:
            d(id, .organize, "Split PDF",
              "Separate pages or ranges into independent PDF files.",
              "scissors", pdf, multiple: false)
        case .removePages:
            d(id, .organize, "Remove Pages",
              "Delete the pages you don't need from a PDF.",
              "trash", pdf, multiple: false)
        case .extractPages:
            d(id, .organize, "Extract Pages",
              "Pull selected pages out into a new PDF.",
              "doc.on.doc", pdf, multiple: false)
        case .organize:
            d(id, .organize, "Organize PDF",
              "Reorder, rotate, delete, and insert pages.",
              "square.grid.2x2", pdf, multiple: false)

        // Optimize
        case .compress:
            d(id, .optimize, "Compress PDF",
              "Reduce file size while keeping the best quality possible.",
              "arrow.down.right.and.arrow.up.left", pdf, multiple: true)
        case .repair:
            d(id, .optimize, "Repair PDF",
              "Recover data from a damaged or corrupt PDF.",
              "wrench.and.screwdriver", pdf, multiple: true)
        case .ocr:
            d(id, .optimize, "OCR PDF",
              "Make scanned PDFs searchable and selectable.",
              "text.viewfinder", pdf, multiple: true)

        // Convert to PDF
        case .imagesToPDF:
            d(id, .convertToPDF, "Images to PDF",
              "Turn JPG, PNG, HEIC, and other images into a PDF.",
              "photo.on.rectangle", images, multiple: true)
        case .wordToPDF:
            d(id, .convertToPDF, "Word to PDF",
              "Convert DOCX, DOC, RTF, and ODT documents to PDF.",
              "doc.richtext", word, multiple: true)
        case .powerPointToPDF:
            d(id, .convertToPDF, "PowerPoint to PDF",
              "Convert PPTX and PPT slideshows to PDF.",
              "rectangle.on.rectangle.angled", powerPoint, multiple: true)
        case .excelToPDF:
            d(id, .convertToPDF, "Excel to PDF",
              "Convert XLSX and XLS spreadsheets to PDF.",
              "tablecells", excel, multiple: true)
        case .htmlToPDF:
            d(id, .convertToPDF, "HTML to PDF",
              "Convert local HTML pages and web archives to PDF.",
              "chevron.left.forwardslash.chevron.right", html, multiple: true)

        // Convert from PDF
        case .pdfToImages:
            d(id, .convertFromPDF, "PDF to Images",
              "Export every page as JPG, PNG, HEIC, or TIFF, or extract embedded images.",
              "photo.stack", pdf, multiple: true)
        case .pdfToWord:
            d(id, .convertFromPDF, "PDF to Word",
              "Convert PDFs into editable DOCX documents.",
              "doc.text", pdf, multiple: true)
        case .pdfToPowerPoint:
            d(id, .convertFromPDF, "PDF to PowerPoint",
              "Turn PDF pages into editable PPTX slides.",
              "play.rectangle", pdf, multiple: true)
        case .pdfToExcel:
            d(id, .convertFromPDF, "PDF to Excel",
              "Pull tables out of PDFs into XLSX or CSV spreadsheets.",
              "tablecells.badge.ellipsis", pdf, multiple: true)
        case .pdfToPDFA:
            d(id, .convertFromPDF, "PDF to PDF/A",
              "Convert to PDF/A for long-term archiving.",
              "archivebox", pdf, multiple: true)
        case .pdfToMarkdown:
            d(id, .convertFromPDF, "PDF to Markdown",
              "Convert PDFs to Markdown with headings, lists, and tables.",
              "number", pdf, multiple: true)

        // Edit
        case .edit:
            d(id, .edit, "Edit PDF",
              "Add text, images, shapes, and drawings to a PDF.",
              "pencil.tip.crop.circle", pdf, multiple: false)
        case .rotate:
            d(id, .edit, "Rotate PDF",
              "Rotate pages the way you need them.",
              "rotate.right", pdf, multiple: true)
        case .pageNumbers:
            d(id, .edit, "Add Page Numbers",
              "Number pages with your choice of position, format, and font.",
              "list.number", pdf, multiple: true)
        case .watermark:
            d(id, .edit, "Add Watermark",
              "Stamp text or an image over your PDF.",
              "drop.halffull", pdf, multiple: true)
        case .crop:
            d(id, .edit, "Crop PDF",
              "Trim margins or select an area to keep on each page.",
              "crop", pdf, multiple: false)
        case .forms:
            d(id, .edit, "PDF Forms",
              "Fill in forms, or turn a PDF into a fillable form.",
              "list.bullet.rectangle", pdf, multiple: false)

        // Security
        case .unlock:
            d(id, .security, "Unlock PDF",
              "Remove passwords and restrictions from PDFs you own.",
              "lock.open", pdf, multiple: true)
        case .protect:
            d(id, .security, "Protect PDF",
              "Encrypt a PDF with a password and set permissions.",
              "lock", pdf, multiple: true)
        case .sign:
            d(id, .security, "Sign PDF",
              "Draw, type, or place your signature on a PDF.",
              "signature", pdf, multiple: false)
        case .redact:
            d(id, .security, "Redact PDF",
              "Permanently remove sensitive text and images.",
              "eye.slash", pdf, multiple: false)
        case .compare:
            d(id, .security, "Compare PDF",
              "Show the differences between two versions of a document.",
              "rectangle.split.2x1", pdf, multiple: true)

        // Intelligence
        case .summarize:
            d(id, .intelligence, "Summarize PDF",
              "Get a summary of a document, generated entirely on your Mac.",
              "text.line.3.summary", pdf, multiple: false)
        case .translate:
            d(id, .intelligence, "Translate PDF",
              "Translate a PDF on device while keeping its layout.",
              "translate", pdf, multiple: false)
        }
    }

    /// Tools with a working, tested `PDFOperation`. Everything else shows "Coming soon".
    private static let implemented: Set<ToolID> = [
        .merge, .split, .removePages, .extractPages, .organize,
        .compress,
        .imagesToPDF, .pdfToImages,
        .rotate, .pageNumbers, .watermark, .crop,
        .unlock, .protect,
        .ocr, .repair,
    ]

    /// Terse constructor so each catalog entry reads as one block.
    /// A tool is unavailable until it is listed in `implemented`.
    private static func d(
        _ id: ToolID, _ category: ToolCategory, _ title: String, _ summary: String,
        _ systemImage: String, _ inputs: [UTType], multiple: Bool
    ) -> ToolDescriptor {
        ToolDescriptor(
            id: id, category: category, title: title, summary: summary,
            systemImage: systemImage, acceptedInputs: inputs,
            allowsMultipleInputs: multiple, isAvailable: implemented.contains(id)
        )
    }

    // MARK: - Input type groups

    private static let pdf: [UTType] = [.pdf]
    private static let images: [UTType] = [.image]
    private static let word: [UTType] = [
        system("org.openxmlformats.wordprocessingml.document"),
        system("com.microsoft.word.doc"),
        .rtf,
        system("org.oasis-open.opendocument.text"),
    ]
    private static let powerPoint: [UTType] = [
        system("org.openxmlformats.presentationml.presentation"),
        system("com.microsoft.powerpoint.ppt"),
        system("org.oasis-open.opendocument.presentation"),
    ]
    private static let excel: [UTType] = [
        system("org.openxmlformats.spreadsheetml.sheet"),
        system("com.microsoft.excel.xls"),
        system("org.oasis-open.opendocument.spreadsheet"),
    ]
    private static let html: [UTType] = [.html, .webArchive]

    /// A type the system declares but `UniformTypeIdentifiers` has no constant for.
    /// Falls back to an imported declaration so the catalog never contains a nil.
    private static func system(_ identifier: String) -> UTType {
        UTType(identifier) ?? UTType(importedAs: identifier)
    }
}
