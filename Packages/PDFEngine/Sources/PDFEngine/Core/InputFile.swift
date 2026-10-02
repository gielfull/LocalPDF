import Foundation

/// One file handed to an operation. `id` is unique per instance, so the same URL
/// added twice (e.g. merging a file with itself) stays two distinct inputs.
public struct InputFile: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let url: URL
    /// Password for an encrypted input, when the user supplied one.
    public var password: String?

    public init(url: URL, password: String? = nil) {
        self.id = UUID()
        self.url = url
        self.password = password
    }
}
