import PDFEngine
import SwiftUI

/// Settings: where results go, how name collisions are handled, and the default
/// compression level.
struct SettingsView: View {
    @Environment(Preferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section {
                LabeledContent("Save results to") {
                    VStack(alignment: .trailing, spacing: 4) {
                        Label(preferences.outputFolderDisplayPath, systemImage: "folder")
                            .lineLimit(1)
                            .truncationMode(.middle)
                        HStack {
                            Button("Reset to Downloads") { preferences.resetOutputFolder() }
                                .disabled(!preferences.isCustomFolder)
                            Button("Choose…") { preferences.chooseOutputFolder() }
                        }
                    }
                }
                if let error = preferences.folderError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Picker("If a file already exists", selection: .constant(0)) {
                    Text("Keep both, adding a number").tag(0)
                }
                .disabled(true)
            } header: {
                Text("Output")
            } footer: {
                Text("Originals are never changed. Results are saved as new files, e.g. \u{201C}report 2.pdf\u{201D}.")
            }

            Section("Compress PDF") {
                Picker("Default level", selection: $preferences.defaultCompressionLevel) {
                    ForEach(CompressOperation.Level.allCases, id: \.self) { level in
                        Text(level.title).tag(level)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }
}
