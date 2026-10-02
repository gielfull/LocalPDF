import UniformTypeIdentifiers

/// Static, UI-facing description of a tool. Pure data so the UI can render the catalog
/// without knowing how a tool is implemented.
public struct ToolDescriptor: Sendable, Hashable, Identifiable {
    public let id: ToolID
    public let category: ToolCategory
    /// Short title, e.g. "Merge PDF".
    public let title: String
    /// One line, like iLovePDF's tile copy.
    public let summary: String
    /// SF Symbol name.
    public let systemImage: String
    /// File types the tool's picker and drop zone accept.
    public let acceptedInputs: [UTType]
    /// Whether the tool takes more than one file: either it combines them (Merge,
    /// Images to PDF, Compare) or it batch-processes each file independently.
    public let allowsMultipleInputs: Bool
    /// `false` until the tool is implemented; the UI shows "Coming soon".
    public let isAvailable: Bool
}
