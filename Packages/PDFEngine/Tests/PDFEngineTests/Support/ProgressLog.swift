import Synchronization

/// Records progress callbacks from any thread.
final class ProgressLog: Sendable {
    private let storage = Mutex<[Double]>([])
    func append(_ value: Double) { storage.withLock { $0.append(value) } }
    var values: [Double] { storage.withLock { $0 } }
}
