import Foundation
import PDFKit
import UniformTypeIdentifiers

/// A file the user added: where it is plus the facts the UI needs (kind, size, pages,
/// encryption), read once off the main actor.
nonisolated struct SourceFile: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable { case pdf, image, other }

    let id: UUID
    let url: URL
    let kind: Kind
    let contentType: UTType?
    let byteCount: Int64
    /// Pages in a PDF (1 for an image). 0 while a locked PDF hasn't been unlocked.
    var pageCount: Int
    /// Size of the first page in points, as displayed (rotation applied), for previews.
    var firstPageSize: CGSize?
    /// Encrypted in any way, including permission-only restrictions.
    let isEncrypted: Bool
    /// Needs an open password before its pages can be read.
    var isLocked: Bool
    var password: String?
    /// A PDF whose first pages have no extractable text, like a scan. False while locked.
    var looksScanned = false

    var name: String { url.lastPathComponent }
    var needsPassword: Bool { isLocked && password == nil }

    var thumbnail: ThumbnailSource {
        ThumbnailSource(url: url, kind: kind == .image ? .image : .pdfPage(0), password: password)
    }

    func thumbnail(page: Int) -> ThumbnailSource {
        ThumbnailSource(url: url, kind: .pdfPage(page), password: password)
    }

    /// "12 pages · 2.4 MB", or just the size for images.
    var detail: String {
        let size = byteCount.formatted(.byteCount(style: .file))
        switch kind {
        case .pdf where isLocked && password == nil: return "Locked · \(size)"
        case .pdf: return "\(pageCount) \(pageCount == 1 ? "page" : "pages") · \(size)"
        default: return size
        }
    }

    func conforms(to types: [UTType]) -> Bool {
        guard let contentType else { return false }
        return types.contains { contentType.conforms(to: $0) }
    }

    /// Reads the file's facts. Never fails: an unreadable PDF reports zero pages.
    @concurrent
    static func load(_ url: URL) async -> SourceFile {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let values = try? url.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey])
        let type = values?.contentType ?? UTType(filenameExtension: url.pathExtension)
        let kind: Kind = if type?.conforms(to: .pdf) == true {
            .pdf
        } else if type?.conforms(to: .image) == true {
            .image
        } else {
            .other
        }

        var file = SourceFile(
            id: UUID(), url: url, kind: kind, contentType: type,
            byteCount: Int64(values?.fileSize ?? 0), pageCount: kind == .image ? 1 : 0,
            firstPageSize: nil, isEncrypted: false, isLocked: false, password: nil
        )
        if kind == .pdf, let document = PDFDocument(url: url) {
            file = SourceFile(
                id: file.id, url: url, kind: kind, contentType: type, byteCount: file.byteCount,
                pageCount: document.isLocked ? 0 : document.pageCount,
                firstPageSize: document.isLocked ? nil : Self.displaySize(of: document.page(at: 0)),
                isEncrypted: document.isEncrypted, isLocked: document.isLocked, password: nil,
                looksScanned: !document.isLocked && Self.looksScanned(document)
            )
        }
        return file
    }

    /// Loads several files, keeping their order.
    static func load(_ urls: [URL]) async -> [SourceFile] {
        var files: [SourceFile] = []
        for url in urls {
            files.append(await load(url))
        }
        return files
    }

    /// Checks `password` against the file. On success returns the file unlocked, with
    /// its page facts filled in; nil if the password is wrong.
    func unlocked(with password: String) -> SourceFile? {
        guard let document = PDFDocument(url: url) else { return nil }
        if document.isLocked, !document.unlock(withPassword: password) { return nil }
        var copy = self
        copy.password = password
        copy.isLocked = false
        copy.pageCount = document.pageCount
        copy.firstPageSize = Self.displaySize(of: document.page(at: 0))
        copy.looksScanned = Self.looksScanned(document)
        return copy
    }

    /// No text on any of the first three pages: cheap, and enough to tell a scan from a
    /// born-digital PDF, whose first pages almost always have some.
    private static func looksScanned(_ document: PDFDocument) -> Bool {
        let probed = min(document.pageCount, 3)
        guard probed > 0 else { return false }
        return (0..<probed).allSatisfy { index in
            document.page(at: index)?.string?.contains { !$0.isWhitespace } != true
        }
    }

    private static func displaySize(of page: PDFPage?) -> CGSize? {
        guard let page else { return nil }
        let size = page.bounds(for: .cropBox).size
        return page.rotation % 180 == 0 ? size : CGSize(width: size.height, height: size.width)
    }
}
