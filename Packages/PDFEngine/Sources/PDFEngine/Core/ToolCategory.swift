/// The sidebar sections, in display order. Display titles and tints are a UI concern
/// and live in the app, not here.
public enum ToolCategory: String, Codable, Sendable, CaseIterable, Hashable {
    case organize, optimize, convertToPDF, convertFromPDF, edit, security, intelligence
}
