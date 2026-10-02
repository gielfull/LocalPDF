import Foundation
import PDFEngine

/// Runs one job off the main actor: holds security-scoped access to inputs and the
/// output folder for the duration, runs the operation, moves its outputs from the temp
/// working directory into the output folder (never overwriting), and deletes the
/// working directory afterwards.
nonisolated enum JobExecutor {
    @concurrent
    static func execute(
        _ request: JobRequest, to destination: OutputDestination,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [SavedOutput] {
        let scopedInputs = request.inputs.map(\.url).filter { $0.startAccessingSecurityScopedResource() }
        defer { scopedInputs.forEach { $0.stopAccessingSecurityScopedResource() } }

        let outputs: [OutputFile]
        do {
            outputs = try await request.run(progress: progress)
        } catch is CancellationError {
            throw PDFEngineError.cancelled
        }
        defer { removeWorkingDirectories(of: outputs) }

        guard !Task.isCancelled else { throw PDFEngineError.cancelled }
        return try move(outputs, to: destination)
    }

    private static func move(_ outputs: [OutputFile], to destination: OutputDestination) throws -> [SavedOutput] {
        let folder = destination.folder
        let scoped = destination.isSecurityScoped && folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }

        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw PDFEngineError.writeFailed(folder)
        }

        var saved: [SavedOutput] = []
        for output in outputs {
            let name = OutputNamer.uniqueName(for: OutputNamer.sanitized(output.suggestedName)) {
                fileManager.fileExists(atPath: folder.appending(path: $0).path(percentEncoded: false))
            }
            let target = folder.appending(path: name)
            do {
                try fileManager.moveItem(at: output.url, to: target)
            } catch {
                throw PDFEngineError.writeFailed(target)
            }
            let size = (try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { $0 } ?? 0
            saved.append(SavedOutput(url: target, byteCount: Int64(size)))
        }
        return saved
    }

    /// Deletes the per-job directories under the engine's temp root that held `outputs`.
    private static func removeWorkingDirectories(of outputs: [OutputFile]) {
        let root = engineTempRoot.resolvingSymlinksInPath().pathComponents
        var directories = Set<URL>()
        for output in outputs {
            let components = output.url.resolvingSymlinksInPath().pathComponents
            // Only ever delete <root>/<job-id>, never anything outside the temp root.
            guard components.count > root.count + 1, Array(components.prefix(root.count)) == root else { continue }
            directories.insert(URL(filePath: NSString.path(withComponents: Array(components.prefix(root.count + 1)))))
        }
        directories.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    /// Where `WorkingDirectory.make()` puts job directories.
    static var engineTempRoot: URL {
        FileManager.default.temporaryDirectory.appending(path: "PDFEngine", directoryHint: .isDirectory)
    }

    /// Removes working directories left behind by jobs that failed or were cancelled in a
    /// previous run. Only call at launch, before any job starts.
    @concurrent
    static func sweepLeftoverWorkingDirectories() async {
        try? FileManager.default.removeItem(at: engineTempRoot)
    }
}
