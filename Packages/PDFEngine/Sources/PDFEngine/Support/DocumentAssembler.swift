import Foundation
import PDFKit

/// Builds a new, unencrypted document from pages of one or more open documents.
///
/// Pages are copied rather than moved: a page may appear twice (Organize's duplicates),
/// and pages of permission-restricted files can't be edited in place (PDFKit silently
/// ignores e.g. a rotation change), while their copies can.
///
/// PDFKit keeps no structure when pages change documents, so the assembler carries it
/// over: internal links and outline entries are remapped to the copied pages, and the ones
/// pointing at pages that didn't make it into the output are dropped.
struct DocumentAssembler {
    let document = PDFDocument()
    /// Source page → its first copy in `document`.
    private var copies: [ObjectIdentifier: PDFPage] = [:]
    /// Internal links on copied pages, with their targets in the source documents.
    private var pendingLinks: [PendingLink] = []

    private struct PendingLink {
        let annotation: PDFAnnotation
        let page: PDFPage
        let target: PDFDestination
        /// The target came from a GoTo action rather than a `/Dest`.
        let isAction: Bool
    }

    var pageCount: Int { document.pageCount }

    /// Appends a copy of `page` and returns the copy.
    @discardableResult
    mutating func append(copyOf page: PDFPage) -> PDFPage {
        // PDFPage's NSCopying conformance always returns a PDFPage.
        let copy = page.copy() as! PDFPage
        // Read link targets before inserting: PDFKit resolves them lazily against the
        // annotation's current document, and the source page isn't in the new one.
        let links = copy.annotations.compactMap { Self.internalTarget(of: $0) }
        document.insert(copy, at: document.pageCount)
        for (annotation, target, isAction) in links {
            pendingLinks.append(PendingLink(annotation: annotation, page: copy, target: target, isAction: isAction))
        }
        record(copy, for: page)
        return copy
    }

    /// Appends `replacement`, a page of a scratch document (e.g. the stamped version of
    /// `source`), as `source`'s stand-in: it takes `source`'s rotation and annotations, and
    /// links and outline entries that pointed at `source` now point at it.
    mutating func append(_ replacement: PDFPage, standingInFor source: PDFPage) {
        let copy = replacement.copy() as! PDFPage // NSCopying returns a PDFPage, as above.
        document.insert(copy, at: document.pageCount)
        copy.rotation = source.rotation
        for annotation in source.annotations {
            guard let annotationCopy = annotation.copy() as? PDFAnnotation else { continue }
            // The original resolves its target in the source document; the copy can't.
            let link = Self.internalTarget(of: annotation)
            copy.addAnnotation(annotationCopy)
            if let (_, target, isAction) = link {
                pendingLinks.append(PendingLink(annotation: annotationCopy, page: copy,
                                                target: target, isAction: isAction))
            }
        }
        record(copy, for: source)
    }

    /// Appends an empty page of `size` (crop box = media box), rotated clockwise by `rotation`.
    @discardableResult
    mutating func appendBlank(size: CGSize, rotation: Int) -> PDFPage {
        let page = PDFPage()
        let rect = CGRect(origin: .zero, size: size)
        page.setBounds(rect, for: .mediaBox)
        page.setBounds(rect, for: .cropBox)
        document.insert(page, at: document.pageCount)
        page.rotation = PageGeometry.normalized(rotation)
        return page
    }

    /// Copies `source`'s outline (bookmarks) under `parent`, or the output's root when nil.
    func copyOutline(of source: PDFDocument, under parent: PDFOutline? = nil) {
        guard let sourceRoot = source.outlineRoot else { return }
        let target = parent ?? rootOutline()
        copyChildren(of: sourceRoot, into: target)
    }

    /// The output's outline root, created on first use.
    func rootOutline() -> PDFOutline {
        if let root = document.outlineRoot { return root }
        let root = PDFOutline()
        document.outlineRoot = root
        return root
    }

    /// Carries title, author, subject, keywords and creator over from `source`.
    func copyAttributes(of source: PDFDocument) {
        document.documentAttributes = source.documentAttributes
    }

    /// The copy of `destination`'s page in the output, or `nil` if it isn't there.
    func mapped(_ destination: PDFDestination) -> PDFDestination? {
        guard let page = destination.page else { return nil }
        let target: PDFPage
        if page.document === document {
            target = page
        } else if let copy = copies[ObjectIdentifier(page)] {
            target = copy
        } else {
            return nil
        }
        let result = PDFDestination(page: target, at: destination.point)
        result.zoom = destination.zoom
        return result
    }

    /// Remaps internal links, then writes the document to `url`.
    func write(to url: URL, options: [PDFDocumentWriteOption: Any] = [:]) throws {
        remapLinks()
        try DocumentIO.write(document, to: url, options: options)
    }

    // MARK: - Private

    /// Links and bookmarks to a duplicated page go to its first copy.
    private mutating func record(_ copy: PDFPage, for source: PDFPage) {
        let key = ObjectIdentifier(source)
        if copies[key] == nil { copies[key] = copy }
    }

    private func copyChildren(of node: PDFOutline, into parent: PDFOutline) {
        for index in 0..<node.numberOfChildren {
            guard let child = node.child(at: index) else { continue }
            let copy = PDFOutline()
            copy.label = child.label
            var hasTarget = false
            if let destination = child.destination {
                if let target = mapped(destination) {
                    copy.destination = target
                    hasTarget = true
                }
            } else if let goTo = child.action as? PDFActionGoTo {
                if let target = mapped(goTo.destination) {
                    copy.action = PDFActionGoTo(destination: target)
                    hasTarget = true
                }
            } else if let action = child.action {
                // URL and named actions don't reference pages; keep them as they are.
                copy.action = action.copy() as? PDFAction
                hasTarget = copy.action != nil
            }
            copyChildren(of: child, into: copy)
            guard hasTarget || copy.numberOfChildren > 0 else { continue }
            copy.isOpen = child.isOpen
            parent.insertChild(copy, at: parent.numberOfChildren)
        }
    }

    /// A link annotation's page target, if it has one that resolves.
    private static func internalTarget(of annotation: PDFAnnotation) -> (PDFAnnotation, PDFDestination, Bool)? {
        if let destination = annotation.destination, destination.page != nil {
            return (annotation, destination, false)
        }
        if let goTo = annotation.action as? PDFActionGoTo, goTo.destination.page != nil {
            return (annotation, goTo.destination, true)
        }
        return nil
    }

    /// Points internal links at the copied pages; drops links whose target page was left out.
    private func remapLinks() {
        for link in pendingLinks {
            guard let target = mapped(link.target) else {
                link.page.removeAnnotation(link.annotation)
                continue
            }
            if link.isAction {
                link.annotation.action = PDFActionGoTo(destination: target)
            } else {
                link.annotation.destination = target
            }
        }
    }
}
