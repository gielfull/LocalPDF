import AppKit
import SwiftUI

/// The Organize page editor: every page in a grid. Drag to reorder (macOS 27
/// `reorderable()`), click / ⌘-click / ⇧-click to select, and edit the selection with the
/// floating palette or its keyboard shortcuts. Produces `OrganizeOperation.Options.pages`.
struct OrganizeCanvas: View {
    @Bindable var session: ToolSession

    @FocusState private var isFocused: Bool
    @State private var hoveredPage: PagePlan.Page.ID?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: PageGridCell.columns, spacing: 12) {
                ForEach(session.pagePlan.pages) { page in
                    cell(for: page)
                }
                .reorderable()
            }
            .reorderContainer(for: PagePlan.Page.self) { difference in
                let target: PagePlan.Page.ID? = switch difference.destination.position {
                case .before(let id): id
                case .end: nil
                }
                withAnimation(.snappy) { session.pagePlan.move(difference.sources, before: target) }
            }
            .padding(24)
            .padding(.bottom, 64)
        }
        .background {
            // Clicking empty canvas clears the selection, like Finder.
            Color.clear
                .contentShape(.rect)
                .onTapGesture { session.pagePlan.clearSelection() }
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.space) {
            // Like Finder: Space previews the page under the pointer, else the selection.
            let selectedFirst = session.pagePlan.selectedIndices.first.map { session.pagePlan.pages[$0].id }
            guard let page = hoveredPage ?? selectedFirst else { return .ignored }
            session.previewPlanPage(page)
            return .handled
        }
        .onDeleteCommand { withAnimation(.snappy) { session.pagePlan.deleteSelection() } }
        .onCommand(#selector(NSResponder.selectAll(_:))) { session.pagePlan.selectAll() }
        .onAppear { isFocused = true }
        .overlay(alignment: .bottom) {
            OrganizePalette(plan: $session.pagePlan)
                .padding(.bottom, 16)
        }
    }

    private func cell(for page: PagePlan.Page) -> some View {
        let isSelected = session.pagePlan.selection.contains(page.id)
        return PageGridCell(
            thumbnail: page.sourceIndex.flatMap { index in session.file?.thumbnail(page: index) },
            label: page.sourceIndex.map { "\($0 + 1)" } ?? "Blank",
            accessibilityText: accessibilityText(for: page),
            rotation: page.rotation,
            isSelected: isSelected,
            onPreview: page.sourceIndex == nil ? nil : { session.previewPlanPage(page.id) },
            onHoverChange: { hovering in
                if hovering {
                    hoveredPage = page.id
                } else if hoveredPage == page.id {
                    hoveredPage = nil
                }
            }
        )
        .onTapGesture {
            isFocused = true
            session.pagePlan.click(page.id, modifier: .current)
        }
        .contextMenu { contextMenu(for: page, isSelected: isSelected) }
    }

    /// Right-click acts on the selection when the page is part of it, otherwise on just
    /// that page (selecting it first), as in Finder.
    @ViewBuilder
    private func contextMenu(for page: PagePlan.Page, isSelected: Bool) -> some View {
        if page.sourceIndex != nil {
            Button("Preview Page", systemImage: "magnifyingglass") { session.previewPlanPage(page.id) }
            Divider()
        }
        Button("Rotate Left", systemImage: "rotate.left") { edit(page, isSelected) { $0.rotateSelection(by: -90) } }
        Button("Rotate Right", systemImage: "rotate.right") { edit(page, isSelected) { $0.rotateSelection(by: 90) } }
        Button("Duplicate", systemImage: "plus.square.on.square") { edit(page, isSelected) { $0.duplicateSelection() } }
        Button("Insert Blank Page After", systemImage: "doc.badge.plus") { edit(page, isSelected) { $0.insertBlankAfterSelection() } }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { edit(page, isSelected) { $0.deleteSelection() } }
    }

    private func edit(_ page: PagePlan.Page, _ isSelected: Bool, _ change: (inout PagePlan) -> Void) {
        if !isSelected {
            session.pagePlan.click(page.id, modifier: .none)
        }
        withAnimation(.snappy) { change(&session.pagePlan) }
    }

    private func accessibilityText(for page: PagePlan.Page) -> String {
        guard let index = page.sourceIndex else { return "Blank page" }
        var text = "Page \(index + 1) of \(session.file?.name ?? "the document")"
        if page.rotation != 0 { text += ", rotated \(page.rotation)°" }
        return text
    }
}

extension PagePlan.ClickModifier {
    /// The modifier keys held during the current click.
    static var current: Self {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) { return .command }
        if flags.contains(.shift) { return .shift }
        return .none
    }
}
