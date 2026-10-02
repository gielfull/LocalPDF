import PDFEngine

/// Which tools to offer for files dropped on the home screen.
///
/// - A PDF that looks scanned (no text on its first pages) suggests OCR, first. A locked
///   PDF can't be inspected, so it never looks scanned and Unlock leads instead.
/// - An encrypted PDF suggests Unlock.
/// - Two or more PDFs suggest Merge; any PDF over 5 MB suggests Compress.
/// - Then the everyday PDF tools: Organize and Split for a single PDF (they take one
///   file), Compress and Unlock for any number. Unlock is offered even when nothing
///   looks encrypted: it's among the most used tools, and some restrictions (or a
///   password the user knows about) aren't obvious from the file list.
/// - Images suggest Images to PDF.
nonisolated enum SmartSuggestions {
    /// "Large" in the same decimal megabytes Finder shows.
    static let largeFileThreshold: Int64 = 5_000_000

    static func tools(for files: [SourceFile]) -> [ToolID] {
        let pdfs = files.filter { $0.kind == .pdf }
        let hasImages = files.contains { $0.kind == .image }
        var tools: [ToolID] = []

        if pdfs.contains(where: \.looksScanned) { tools.append(.ocr) }
        if pdfs.contains(where: \.isEncrypted) { tools.append(.unlock) }
        if pdfs.count >= 2 { tools.append(.merge) }
        if pdfs.contains(where: { $0.byteCount > largeFileThreshold }) { tools.append(.compress) }
        if pdfs.count == 1 { tools += [.organize, .split] }
        if !pdfs.isEmpty { tools += [.compress, .unlock] }
        if hasImages { tools.append(.imagesToPDF) }

        var seen = Set<ToolID>()
        return tools.filter { seen.insert($0).inserted }
    }

    /// The subset of `files` to preload into `tool`: only types it accepts, only the
    /// encrypted PDFs for Unlock, only the scanned ones for OCR, and just the first file
    /// for single-input tools.
    static func files(_ files: [SourceFile], for tool: ToolID) -> [SourceFile] {
        let descriptor = ToolCatalog.descriptor(for: tool)
        var accepted = files.filter { $0.conforms(to: descriptor.acceptedInputs) }
        if tool == .unlock, accepted.contains(where: \.isEncrypted) {
            accepted = accepted.filter(\.isEncrypted)
        }
        if tool == .ocr, accepted.contains(where: \.looksScanned) {
            accepted = accepted.filter(\.looksScanned)
        }
        return descriptor.allowsMultipleInputs ? accepted : Array(accepted.prefix(1))
    }
}
