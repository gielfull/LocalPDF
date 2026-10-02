/// The frame every operation's `run` uses: a progress reporter, a fresh output directory
/// (removed again if the job fails), and the final "done" report.
enum Job {
    static func run(
        reportingTo progress: @Sendable (Double) -> Void,
        _ body: (inout ProgressReporter, inout OutputDirectory) throws -> [OutputFile]
    ) throws -> [OutputFile] {
        // The reporter only lives for this call, so the closure never actually escapes.
        try withoutActuallyEscaping(progress) { sink in
            var reporter = ProgressReporter(sink)
            let outputs = try OutputDirectory.run { directory in
                try body(&reporter, &directory)
            }
            reporter.finish()
            return outputs
        }
    }

    /// Runs `body` once per input, each input being an equal share of the progress.
    /// - Throws: `.unsupportedInput` when `inputs` is empty.
    static func forEach(
        _ inputs: [InputFile],
        reportingTo progress: @Sendable (Double) -> Void,
        _ body: (InputFile, inout ProgressReporter, inout OutputDirectory) throws -> [OutputFile]
    ) throws -> [OutputFile] {
        guard !inputs.isEmpty else { throw PDFEngineError.unsupportedInput(DocumentIO.noInputURL) }
        return try run(reportingTo: progress) { reporter, directory in
            var outputs: [OutputFile] = []
            for (index, input) in inputs.enumerated() {
                try reporter.beginItem(index, of: inputs.count)
                outputs += try body(input, &reporter, &directory)
            }
            return outputs
        }
    }

    /// `run(reportingTo:_:)` for bodies that await (OCR's Vision requests).
    static func run(
        reportingTo progress: @Sendable (Double) -> Void,
        _ body: (inout ProgressReporter, inout OutputDirectory) async throws -> [OutputFile]
    ) async throws -> [OutputFile] {
        try await withoutActuallyEscaping(progress) { sink in
            var reporter = ProgressReporter(sink)
            let outputs = try await OutputDirectory.run { directory in
                try await body(&reporter, &directory)
            }
            reporter.finish()
            return outputs
        }
    }

    /// `forEach(_:reportingTo:_:)` for bodies that await.
    static func forEach(
        _ inputs: [InputFile],
        reportingTo progress: @Sendable (Double) -> Void,
        _ body: (InputFile, inout ProgressReporter, inout OutputDirectory) async throws -> [OutputFile]
    ) async throws -> [OutputFile] {
        guard !inputs.isEmpty else { throw PDFEngineError.unsupportedInput(DocumentIO.noInputURL) }
        return try await run(reportingTo: progress) { reporter, directory in
            var outputs: [OutputFile] = []
            for (index, input) in inputs.enumerated() {
                try reporter.beginItem(index, of: inputs.count)
                outputs += try await body(input, &reporter, &directory)
            }
            return outputs
        }
    }
}
