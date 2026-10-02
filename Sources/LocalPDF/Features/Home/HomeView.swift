import PDFEngine
import SwiftUI

/// "All Tools": the drop zone with smart suggestions, then every tool by category.
struct HomeView: View {
    let staged: [SourceFile]
    let isStaging: Bool
    let suggestions: [ToolID]
    let searchText: String
    /// The category's tools that match the search.
    let tools: (ToolCategory) -> [ToolDescriptor]
    let onOpenTool: (ToolID) -> Void
    let onPickSuggestion: (ToolID) -> Void
    let onDrop: ([URL]) -> Void
    let onAddFiles: () -> Void
    let onClearStaged: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if searchText.isEmpty {
                    VStack(alignment: .leading, spacing: 28) {
                        HomeHeader()
                        DropZone(
                            title: staged.isEmpty ? "Drop PDFs or images here" : "What do you want to do?",
                            subtitle: staged.isEmpty
                                ? "LocalPDF suggests the right tool. Files never leave your Mac."
                                : "Pick a suggestion, or drop different files.",
                            onDrop: onDrop, onAdd: onAddFiles
                        ) {
                            if isStaging {
                                ProgressView().controlSize(.small)
                            } else if !staged.isEmpty {
                                StagedFilesView(
                                    files: staged, suggestions: suggestions,
                                    onPick: onPickSuggestion, onClear: onClearStaged
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 1200)
                    .frame(maxWidth: .infinity)
                    .background(alignment: .top) {
                        HeroWash()
                    }
                }
                toolSections
                    .padding(.horizontal, 32)
                    .padding(.top, searchText.isEmpty ? 0 : 24)
                    .padding(.bottom, 32)
                    .frame(maxWidth: 1200)
                    .frame(maxWidth: .infinity)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle("All Tools")
    }

    @ViewBuilder
    private var toolSections: some View {
        let sections = ToolCategory.allCases.map { ($0, tools($0)) }.filter { !$0.1.isEmpty }
        if sections.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxWidth: .infinity, minHeight: 320)
        } else {
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(sections, id: \.0) { category, tools in
                        CategorySection(category: category, tools: tools, onOpen: onOpenTool)
                    }
                }
            }
        }
    }
}

/// The title block above the drop zone.
private struct HomeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Every PDF tool, right on your Mac")
                .font(.largeTitle.weight(.bold))
            Label("Works offline. Your files never leave this Mac.", systemImage: "lock.shield")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A soft wash of the category tints behind the header. `backgroundExtensionEffect()`
/// carries it under the floating sidebar, so the top of Home reads edge to edge.
private struct HeroWash: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        LinearGradient(
            colors: [Color.red, .orange, .purple, .blue].map { $0.opacity(reduceTransparency ? 0.05 : 0.14) },
            startPoint: .leading, endPoint: .trailing
        )
        .mask {
            LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
        }
        .frame(height: 360)
        .backgroundExtensionEffect()
        .accessibilityHidden(true)
    }
}

/// One category: a tinted heading and its tiles.
private struct CategorySection: View {
    let category: ToolCategory
    let tools: [ToolDescriptor]
    let onOpen: (ToolID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(category.style.tint)
                    .frame(width: 8, height: 8)
                Text(category.style.title)
                    .font(.title3.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)], spacing: 16) {
                ForEach(tools) { tool in
                    ToolTile(tool: tool) { onOpen(tool.id) }
                }
            }
        }
    }
}
