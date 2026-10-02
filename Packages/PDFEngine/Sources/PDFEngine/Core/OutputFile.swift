import Foundation

/// One result of an operation. Operations write into a `WorkingDirectory`; the app
/// moves the file to its final destination, so inputs are never touched in place.
public struct OutputFile: Sendable, Hashable {
    /// A temp location; the app moves it to the final destination.
    public let url: URL
    /// File name to offer the user, e.g. "localpdf_compress_report.pdf".
    public let suggestedName: String

    public init(url: URL, suggestedName: String) {
        self.url = url
        self.suggestedName = suggestedName
    }
}
