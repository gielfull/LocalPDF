import PDFEngine
import SwiftUI

/// Split, Remove Pages and Extract Pages: the file's pages, where clicking a page toggles
/// it in the range text and typing a range highlights the pages (`PageRangeSync`).
/// Any page can be previewed large: right-click › Preview Page, the hover magnifier, or
/// Space over a page.
struct PageSelectionCanvas: View {
    @Bindable var session: ToolSession

    @State private var hoveredIndex: Int?
    @FocusState private var isFocused: Bool

    var body: some View {
        if let file = session.file {
            let selected = PageRangeSync.pages(in: session.rangeText, pageCount: file.pageCount)
            let groups = session.tool == .split ? session.splitGroups : [:]
            ScrollView {
                LazyVGrid(columns: PageGridCell.columns, spacing: 12) {
                    ForEach(0..<file.pageCount, id: \.self) { index in
                        cell(index, file: file, selected: selected, groups: groups)
                    }
                }
                .padding(24)
                .padding(.bottom, 56)
            }
            .safeAreaInset(edge: .bottom) {
                CanvasHint(text: hint)
            }
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onKeyPress(.space) {
                guard let page = hoveredIndex ?? selected.sorted().first else { return .ignored }
                session.previewPage(page)
                return .handled
            }
            .onAppear { isFocused = true }
        }
    }

    private func cell(_ index: Int, file: SourceFile, selected: Set<Int>, groups: [Int: Int]) -> some View {
        let isSelected: Bool
        var isDimmed = false
        var badge: PageGridCell.Badge?
        switch session.tool {
        case .split:
            let group = groups[index]
            isSelected = session.splitMode == .ranges && group != nil
            isDimmed = group == nil
            badge = group.map { PageGridCell.Badge(text: "File \($0 + 1)", tint: Self.groupTint($0)) }
        case .removePages:
            isSelected = selected.contains(index)
            isDimmed = isSelected
        default:
            isSelected = selected.contains(index)
            isDimmed = !selected.isEmpty && !isSelected
        }
        return PageGridCell(
            thumbnail: file.thumbnail(page: index),
            label: "\(index + 1)",
            accessibilityText: "Page \(index + 1) of \(file.name)",
            isSelected: isSelected,
            emphasis: session.tool == .removePages ? .remove : .select,
            isDimmed: isDimmed,
            badge: badge,
            onPreview: { session.previewPage(index) },
            onHoverChange: { hovering in
                if hovering {
                    hoveredIndex = index
                } else if hoveredIndex == index {
                    hoveredIndex = nil
                }
            }
        )
        .onTapGesture {
            isFocused = true
            toggle(index, pageCount: file.pageCount)
        }
        .contextMenu {
            Button("Preview Page", systemImage: "magnifyingglass") { session.previewPage(index) }
            Divider()
            Button(toggleTitle(isIncluded: isSelected), systemImage: toggleSymbol) {
                toggle(index, pageCount: file.pageCount)
            }
        }
    }

    /// The context-menu wording for clicking a page, per tool.
    private func toggleTitle(isIncluded: Bool) -> String {
        switch session.tool {
        case .removePages: isIncluded ? "Keep Page" : "Remove Page"
        case .extractPages: isIncluded ? "Don\u{2019}t Extract Page" : "Extract Page"
        default: isIncluded ? "Remove from Ranges" : "Add to Ranges"
        }
    }

    private var toggleSymbol: String {
        session.tool == .removePages ? "trash" : "checkmark.circle"
    }

    private func toggle(_ index: Int, pageCount: Int) {
        if session.tool == .split, session.splitMode != .ranges {
            session.splitMode = .ranges
            session.rangeText = ""
        }
        session.rangeText = PageRangeSync.toggling(index, in: session.rangeText, pageCount: pageCount)
    }

    private var hint: String {
        switch session.tool {
        case .removePages: "Click the pages to remove"
        case .extractPages: "Click the pages to extract"
        default: "Click pages to build the ranges · each range becomes a file"
        }
    }

    /// Distinct, legible colors for consecutive output files.
    private static func groupTint(_ group: Int) -> Color {
        let tints: [Color] = [.blue, .orange, .green, .purple, .pink, .teal, .indigo, .brown]
        return tints[group % tints.count]
    }
}
