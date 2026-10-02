import Foundation

/// Where a job moves its outputs: a `Sendable` snapshot of `Preferences` for work that
/// runs off the main actor.
nonisolated struct OutputDestination: Sendable {
    let folder: URL
    /// The folder came from a security-scoped bookmark and needs scoped access to write.
    let isSecurityScoped: Bool
}
