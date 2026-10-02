/// Every tool implements this. Options drive the inspector UI, workflows, App Intents and CLI.
///
/// Implementations are stateless value types: all configuration arrives in `options`,
/// so one `Options` value can be saved as a workflow step and replayed later.
public protocol PDFOperation: Sendable {
    associatedtype Options: Codable & Sendable & Hashable

    /// The tool this operation implements.
    static var tool: ToolID { get }

    init()

    /// Runs the tool. Write outputs into a `WorkingDirectory`, never over an input.
    /// - Parameter progress: fraction complete in `0...1`; may be called from any thread.
    /// - Throws: `PDFEngineError`; check `Task.isCancelled` and throw `.cancelled`.
    func run(_ inputs: [InputFile], options: Options,
             progress: @Sendable (Double) -> Void) async throws -> [OutputFile]
}
