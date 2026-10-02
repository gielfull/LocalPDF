import Foundation
import Observation
import PDFEngine

/// One run of a tool, from submission to its saved results.
@Observable
final class Job: Identifiable {
    enum State: Equatable {
        case running(progress: Double)
        case succeeded
        case failed(message: String)
        case cancelled
    }

    let id = UUID()
    let request: JobRequest
    let startedAt = Date()
    var state: State = .running(progress: 0)
    var outputs: [SavedOutput] = []

    @ObservationIgnored var task: Task<Void, Never>?

    init(request: JobRequest) {
        self.request = request
    }

    var tool: ToolDescriptor { ToolCatalog.descriptor(for: request.tool) }
    var isRunning: Bool { if case .running = state { true } else { false } }
    var isFinished: Bool { !isRunning }

    var outputByteCount: Int64 { outputs.reduce(0) { $0 + $1.byteCount } }

    /// "report.pdf" or "report.pdf and 2 more".
    var inputSummary: String {
        let names = request.inputs.map(\.url.lastPathComponent)
        guard let first = names.first else { return "" }
        return names.count == 1 ? first : "\(first) and \(names.count - 1) more"
    }
}
