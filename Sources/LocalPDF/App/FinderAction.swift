import PDFEngine
import UniformTypeIdentifiers

/// What the user asked for from Finder: Open With (or a drop on the Dock icon), or one of
/// the app's Quick Actions, which are Services declared under `NSServices` in
/// `project.yml`.
///
/// Each Service's `NSMessage` is the raw value here, and `AppDelegate+Services` has the
/// matching `<rawValue>:userData:error:` method. A test checks the three agree.
nonisolated enum FinderAction: String, CaseIterable, Sendable {
    /// "Open in LocalPDF", Open With, or the Dock: the home screen's suggestions.
    case open = "openInLocalPDF"
    case compress = "compressWithLocalPDF"
    case merge = "mergeWithLocalPDF"
    case imagesToPDF = "convertImagesToPDFWithLocalPDF"

    /// Where the files go.
    enum Destination: Equatable, Sendable {
        /// The home screen, staged with suggestions.
        case home
        /// A tool, preloaded with these files in this order.
        case tool(ToolID, [SourceFile])
    }

    /// The tool this action opens; nil for plain Open.
    var tool: ToolID? {
        switch self {
        case .open: nil
        case .compress: .compress
        case .merge: .merge
        case .imagesToPDF: .imagesToPDF
        }
    }

    /// The file types Finder offers this action for (the Service's `NSSendFileTypes`).
    var acceptedTypes: [UTType] {
        tool.map { ToolCatalog.descriptor(for: $0).acceptedInputs } ?? [.pdf, .image]
    }

    /// Routes `files`, kept in the order Finder handed them over. A tool takes the files
    /// it accepts (one-file tools just the first); when the tool isn't available or
    /// accepts none of them, the files land on the home screen instead, so an action
    /// never opens a "Coming soon" screen or an empty tool.
    func destination(
        for files: [SourceFile],
        isAvailable: (ToolID) -> Bool = { ToolCatalog.descriptor(for: $0).isAvailable }
    ) -> Destination {
        guard let tool, isAvailable(tool) else { return .home }
        let accepted = SmartSuggestions.files(files, for: tool)
        return accepted.isEmpty ? .home : .tool(tool, accepted)
    }
}
