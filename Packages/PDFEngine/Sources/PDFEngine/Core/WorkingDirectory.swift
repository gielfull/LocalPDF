import Foundation

/// Temp working directory per job, cleaned up by the caller.
public enum WorkingDirectory {
    /// Creates a fresh, empty directory under the (sandboxed) temporary directory,
    /// e.g. `…/tmp/PDFEngine/<UUID>/`. The caller removes it once outputs are moved.
    public static func make() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "PDFEngine", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
