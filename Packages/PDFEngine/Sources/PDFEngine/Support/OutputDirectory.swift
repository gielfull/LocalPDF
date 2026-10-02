import Foundation

/// One job's fresh `WorkingDirectory`, handing out collision-free output names.
///
/// Two inputs called "report.pdf" from different folders would both suggest
/// "localpdf_rotate_report.pdf"; the second becomes "localpdf_rotate_report 2.pdf" on disk and in the
/// suggested name, so neither output overwrites the other.
struct OutputDirectory {
    let url: URL
    /// Lower-cased, because the default APFS volume is case-insensitive.
    private var usedNames: Set<String> = []

    private init(url: URL) {
        self.url = url
    }

    /// Creates a working directory, runs `body` in it, and removes the directory if
    /// `body` throws (the caller never sees its URL, so nobody else could clean it up).
    static func run(_ body: (inout OutputDirectory) throws -> [OutputFile]) throws -> [OutputFile] {
        let directoryURL: URL
        do {
            directoryURL = try WorkingDirectory.make()
        } catch {
            throw PDFEngineError.writeFailed(FileManager.default.temporaryDirectory)
        }
        var directory = OutputDirectory(url: directoryURL)
        do {
            return try body(&directory)
        } catch {
            try? FileManager.default.removeItem(at: directoryURL)
            throw error
        }
    }

    /// `run(_:)` for bodies that await.
    static func run(_ body: (inout OutputDirectory) async throws -> [OutputFile]) async throws -> [OutputFile] {
        let directoryURL: URL
        do {
            directoryURL = try WorkingDirectory.make()
        } catch {
            throw PDFEngineError.writeFailed(FileManager.default.temporaryDirectory)
        }
        var directory = OutputDirectory(url: directoryURL)
        do {
            return try await body(&directory)
        } catch {
            try? FileManager.default.removeItem(at: directoryURL)
            throw error
        }
    }

    /// Reserves `name` (or "name 2.ext", "name 3.ext", … when taken) in this directory.
    mutating func reserve(_ name: String) -> OutputFile {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = name
        var counter = 2
        while usedNames.contains(candidate.lowercased()) {
            candidate = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            counter += 1
        }
        usedNames.insert(candidate.lowercased())
        return OutputFile(url: url.appending(path: candidate, directoryHint: .notDirectory),
                          suggestedName: candidate)
    }

    /// A scratch file for intermediate results, never returned as an output.
    func scratchURL(extension ext: String) -> URL {
        url.appending(path: ".scratch-\(UUID().uuidString).\(ext)", directoryHint: .notDirectory)
    }
}
