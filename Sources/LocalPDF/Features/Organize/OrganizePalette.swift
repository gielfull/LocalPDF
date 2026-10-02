import SwiftUI

/// The floating glass palette under the Organize grid. Each button carries the keyboard
/// shortcut for its edit, so the shortcuts work whenever the grid is on screen.
struct OrganizePalette: View {
    @Binding var plan: PagePlan

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                cluster {
                    button("Rotate Left", "rotate.left", "l") { plan.rotateSelection(by: -90) }
                    button("Rotate Right", "rotate.right", "r") { plan.rotateSelection(by: 90) }
                }
                cluster {
                    button("Duplicate", "plus.square.on.square", "d") { plan.duplicateSelection() }
                    button("Insert Blank Page", "doc.badge.plus", "n", modifiers: [.command, .shift], needsSelection: false) {
                        plan.insertBlankAfterSelection()
                    }
                }
                cluster {
                    button("Delete", "trash", .delete) { plan.deleteSelection() }
                }
            }
        }
    }

    private func cluster(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 2, content: content)
            .padding(4)
            .glassEffect(.regular, in: .capsule)
    }

    private func button(
        _ title: String, _ systemImage: String, _ key: KeyEquivalent,
        modifiers: EventModifiers = .command, needsSelection: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, systemImage: systemImage) {
            withAnimation(.snappy) { action() }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .frame(width: 36, height: 32)
        .keyboardShortcut(key, modifiers: modifiers)
        .disabled(needsSelection && !plan.hasSelection)
        .help("\(title) (\(shortcutText(key, modifiers)))")
    }

    private func shortcutText(_ key: KeyEquivalent, _ modifiers: EventModifiers) -> String {
        let keyText = key == .delete ? "⌫" : String(key.character).uppercased()
        return (modifiers.contains(.shift) ? "⇧" : "") + "⌘" + keyText
    }
}
