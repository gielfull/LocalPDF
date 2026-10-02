import Foundation

/// Asks the user for a PDF's open password. The sheet checks the password against the
/// file before calling `onSubmit`, so callers only ever receive a working password.
struct PasswordRequest: Identifiable {
    let id = UUID()
    let file: SourceFile
    /// A previous attempt (e.g. a password typed earlier) was rejected.
    var wasRejected = false
    /// Receives the file unlocked with the verified password.
    let onSubmit: (SourceFile) -> Void
}
