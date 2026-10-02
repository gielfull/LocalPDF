import PDFEngine
import SwiftUI

/// The sidebar: All Tools, one section per category (filtered by search), then
/// Workflows and History. Unavailable tools and the not-yet-built Library entries stay
/// selectable but dimmed, with "Soon".
struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selection) {
            Label("All Tools", systemImage: "square.grid.2x2")
                .tag(SidebarItem.home)

            ForEach(ToolCategory.allCases, id: \.self) { category in
                let tools = model.tools(in: category)
                if !tools.isEmpty {
                    Section(category.style.title) {
                        ForEach(tools) { tool in
                            SidebarToolRow(tool: tool)
                                .tag(SidebarItem.tool(tool.id))
                        }
                    }
                }
            }

            Section("Library") {
                SidebarSoonRow(title: "Workflows", systemImage: "gearshape.2")
                    .tag(SidebarItem.workflows)
                SidebarSoonRow(title: "History", systemImage: "clock.arrow.circlepath")
                    .tag(SidebarItem.history)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 320)
    }
}

/// One tool in the sidebar: its symbol in the category tint, and "Soon" if unavailable.
private struct SidebarToolRow: View {
    let tool: ToolDescriptor

    var body: some View {
        Label {
            HStack {
                Text(tool.title)
                    .foregroundStyle(tool.isAvailable ? .primary : .secondary)
                Spacer(minLength: 4)
                if !tool.isAvailable {
                    SoonBadge()
                }
            }
        } icon: {
            Image(systemName: tool.systemImage)
                .foregroundStyle(tool.tint)
                .opacity(tool.isAvailable ? 1 : 0.55)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A Library entry that isn't built yet, styled like an unavailable tool.
private struct SidebarSoonRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                SoonBadge()
            }
        } icon: {
            Image(systemName: systemImage)
                .opacity(0.55)
        }
        .accessibilityElement(children: .combine)
    }
}
