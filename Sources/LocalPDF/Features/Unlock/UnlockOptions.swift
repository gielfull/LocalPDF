import SwiftUI

/// Unlock PDF's inspector section: what will happen to each file.
struct UnlockOptions: View {
    @Bindable var session: ToolSession

    var body: some View {
        Section {
            ForEach(session.files) { file in
                LabeledContent(file.name) {
                    Text(status(of: file))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Files")
        } footer: {
            Text("Saves an unencrypted copy. Files that need a password to open ask for it first. Only unlock files you own.")
        }
    }

    private func status(of file: SourceFile) -> String {
        if file.needsPassword { return "Needs password" }
        if file.password != nil { return "Password entered" }
        return file.isEncrypted ? "Restrictions only" : "Not encrypted"
    }
}
