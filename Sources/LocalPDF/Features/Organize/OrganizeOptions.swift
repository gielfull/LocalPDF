import SwiftUI

/// Organize PDF's inspector section: counts, reset, and the shortcuts.
struct OrganizeOptions: View {
    @Bindable var session: ToolSession

    var body: some View {
        Section("Pages") {
            LabeledContent("In the result", value: "\(session.pagePlan.pages.count)")
            LabeledContent("Selected", value: "\(session.pagePlan.selection.count)")
            Button("Reset All Changes") {
                withAnimation(.snappy) { session.pagePlan.reset() }
            }
            .disabled(!session.pagePlan.isModified)
        }
        Section("Shortcuts") {
            shortcut("Select more", "⌘-click, ⇧-click")
            shortcut("Select all", "⌘A")
            shortcut("Rotate left / right", "⌘L / ⌘R")
            shortcut("Duplicate", "⌘D")
            shortcut("Insert blank page", "⇧⌘N")
            shortcut("Delete", "⌫")
        }
    }

    private func shortcut(_ title: String, _ keys: String) -> some View {
        LabeledContent(title) {
            Text(keys)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}
