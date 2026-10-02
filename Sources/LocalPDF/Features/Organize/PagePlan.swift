import Foundation
import PDFEngine

/// The Organize tool's editable page list and its selection. Pure value logic: the page
/// grid calls these mutations and `instructions` becomes `OrganizeOperation.Options.pages`.
nonisolated struct PagePlan: Equatable, Sendable {
    struct Page: Identifiable, Hashable, Sendable {
        let id: UUID
        /// 0-based page in the source document, or nil for an inserted blank page.
        var sourceIndex: Int?
        /// Extra clockwise rotation, normalized to 0, 90, 180 or 270.
        var rotation: Int

        init(sourceIndex: Int?, rotation: Int = 0) {
            self.id = UUID()
            self.sourceIndex = sourceIndex
            self.rotation = rotation
        }
    }

    /// How a click on a page combines with the existing selection.
    enum ClickModifier { case none, command, shift }

    private(set) var pages: [Page]
    private(set) var selection: Set<Page.ID> = []
    /// Where a ⇧-click range starts.
    private var anchor: Page.ID?
    private var sourcePageCount: Int

    init(pageCount: Int = 0) {
        sourcePageCount = pageCount
        pages = (0..<pageCount).map { Page(sourceIndex: $0) }
    }

    var instructions: [OrganizeOperation.PageInstruction] {
        pages.map { .init(sourcePageIndex: $0.sourceIndex, additionalRotation: $0.rotation) }
    }

    /// Whether anything differs from the untouched document.
    var isModified: Bool {
        pages.map(\.sourceIndex) != Array(0..<sourcePageCount) || pages.contains { $0.rotation != 0 }
    }

    var hasSelection: Bool { !selection.isEmpty }

    /// Selected pages, in page order.
    var selectedIndices: [Int] { pages.indices.filter { selection.contains(pages[$0].id) } }

    // MARK: - Selection

    mutating func click(_ id: Page.ID, modifier: ClickModifier) {
        switch modifier {
        case .none:
            selection = [id]
            anchor = id
        case .command:
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
            anchor = id
        case .shift:
            guard let anchor, let from = pages.firstIndex(where: { $0.id == anchor }),
                  let to = pages.firstIndex(where: { $0.id == id })
            else {
                selection = [id]
                self.anchor = id
                return
            }
            selection = Set(pages[min(from, to)...max(from, to)].map(\.id))
        }
    }

    mutating func selectAll() {
        selection = Set(pages.map(\.id))
    }

    mutating func clearSelection() {
        selection = []
        anchor = nil
    }

    // MARK: - Edits

    /// Rotates the selected pages; `degrees` is ±90 or 180.
    mutating func rotateSelection(by degrees: Int) {
        for index in selectedIndices {
            pages[index].rotation = ((pages[index].rotation + degrees) % 360 + 360) % 360
        }
    }

    mutating func deleteSelection() {
        let firstIndex = selectedIndices.first
        pages.removeAll { selection.contains($0.id) }
        clearSelection()
        // Keep the keyboard flow going: select the page that slid into place.
        if let firstIndex, !pages.isEmpty {
            let next = pages[min(firstIndex, pages.count - 1)].id
            selection = [next]
            anchor = next
        }
    }

    /// Inserts a copy right after each selected page and selects the copies.
    mutating func duplicateSelection() {
        var copies: Set<Page.ID> = []
        for index in selectedIndices.reversed() {
            let copy = Page(sourceIndex: pages[index].sourceIndex, rotation: pages[index].rotation)
            pages.insert(copy, at: index + 1)
            copies.insert(copy.id)
        }
        selection = copies
        anchor = copies.first
    }

    /// Inserts a blank page after the last selected page (or at the end) and selects it.
    mutating func insertBlankAfterSelection() {
        let index = selectedIndices.last.map { $0 + 1 } ?? pages.endIndex
        let blank = Page(sourceIndex: nil)
        pages.insert(blank, at: index)
        selection = [blank.id]
        anchor = blank.id
    }

    /// Applies a drag: `sources` move to just before `target` (nil = the end).
    mutating func move(_ sources: [Page.ID], before target: Page.ID?) {
        pages = Reorder.move(pages, sources: sources, before: target)
    }

    mutating func reset() {
        self = PagePlan(pageCount: sourcePageCount)
    }
}
