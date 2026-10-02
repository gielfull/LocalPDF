import Foundation
import PDFEngine

/// A ready-to-run tool invocation: the operation with its options captured, plus the
/// inputs. Type-erased so the job queue can run any tool without knowing its `Options`.
nonisolated struct JobRequest: Sendable {
    /// How the inputs were protected. Most tools write unencrypted output, so the result
    /// sheet uses this to say when protection was dropped.
    nonisolated enum Protection: Int, Comparable, Sendable {
        case unprotected
        /// Opens without a password but restricts printing, copying or editing.
        case restrictions
        /// Needs a password to open.
        case password

        static func < (lhs: Protection, rhs: Protection) -> Bool { lhs.rawValue < rhs.rawValue }

        /// The strongest protection among `files`. A file that was unlocked with its
        /// password still counts as password-protected.
        static func of(_ files: [SourceFile]) -> Protection {
            files.map { file -> Protection in
                if file.isLocked || file.password != nil { return .password }
                return file.isEncrypted ? .restrictions : .unprotected
            }.max() ?? .unprotected
        }
    }

    let tool: ToolID
    var inputs: [InputFile]
    /// Total size of the inputs, for before/after comparisons.
    let inputByteCount: Int64
    /// The strongest protection among the inputs.
    private(set) var inputProtection: Protection
    private let body: @Sendable ([InputFile], @escaping @Sendable (Double) -> Void) async throws -> [OutputFile]

    init<Operation: PDFOperation>(
        _ operation: Operation.Type, options: Operation.Options,
        inputs: [InputFile], inputByteCount: Int64, inputProtection: Protection = .unprotected
    ) {
        self.tool = Operation.tool
        self.inputs = inputs
        self.inputByteCount = inputByteCount
        self.inputProtection = inputProtection
        self.body = { inputs, progress in
            try await Operation().run(inputs, options: options, progress: progress)
        }
    }

    func run(progress: @escaping @Sendable (Double) -> Void) async throws -> [OutputFile] {
        try await body(inputs, progress)
    }

    /// The same request with `password` set on every input at `url`, which therefore
    /// was password-protected even if the up-front check didn't see it.
    func supplying(password: String, for url: URL) -> JobRequest {
        var copy = self
        copy.inputProtection = .password
        copy.inputs = inputs.map { input in
            guard input.url == url else { return input }
            var input = input
            input.password = password
            return input
        }
        return copy
    }
}
