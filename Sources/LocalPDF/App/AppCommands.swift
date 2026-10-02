import PDFEngine
import SwiftUI

/// Menu bar commands: Add Files (⌘O) in File, and a Tools menu listing every available
/// tool with ⌘1…⌘9 for the first nine in catalog order.
struct AppCommands: Commands {
    let model: AppModel

    var body: some Commands {
        // The window is the app's one workspace, so File > New Window is replaced
        // with Add Files rather than opening a second copy of the same state.
        CommandGroup(replacing: .newItem) {
            Button("Add Files…", action: model.addFiles)
                .keyboardShortcut("o")
        }

        CommandMenu("Tools") {
            Button("All Tools") { model.selection = .home }
                .keyboardShortcut("0")
            Divider()
            let tools = ToolCatalog.all.filter(\.isAvailable)
            if tools.isEmpty {
                Text("No tools available yet")
            }
            ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                Button(tool.title) { model.open(tool.id) }
                    .keyboardShortcut(index < 9 ? KeyEquivalent(Character("\(index + 1)")) : nil)
            }
        }
    }
}

private extension View {
    /// A shortcut when `key` is non-nil.
    @ViewBuilder
    func keyboardShortcut(_ key: KeyEquivalent?) -> some View {
        if let key { keyboardShortcut(key, modifiers: .command) } else { self }
    }
}
