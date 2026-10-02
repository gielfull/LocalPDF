/// Reports monotonic progress in `0...1` and checks for cancellation at every step.
///
/// Batch tools call `beginItem(_:of:)` per input, then `update(_:)` with the fraction of
/// that item; the reporter maps it onto the item's slice of the whole job. Values never
/// go backwards, and `1` is sent exactly once, by `finish()`.
struct ProgressReporter {
    private let sink: @Sendable (Double) -> Void
    private var last = 0.0
    private var itemStart = 0.0
    private var itemLength = 1.0

    init(_ sink: @escaping @Sendable (Double) -> Void) {
        self.sink = sink
        sink(0)
    }

    /// Narrows later `update` calls to item `index` (0-based) of `count`.
    mutating func beginItem(_ index: Int, of count: Int) throws {
        let count = max(count, 1)
        itemStart = Double(index) / Double(count)
        itemLength = 1 / Double(count)
        try update(0)
    }

    /// Reports `fraction` of the current item, after throwing `.cancelled` if the task was.
    mutating func update(_ fraction: Double) throws {
        if Task.isCancelled { throw PDFEngineError.cancelled }
        let clamped = min(max(fraction, 0), 1)
        // Stay below 1 until `finish()`, so "done" is reported once, at the very end.
        let value = min(itemStart + clamped * itemLength, 0.999)
        guard value > last else { return }
        last = value
        sink(value)
    }

    /// Reports completion.
    mutating func finish() {
        guard last < 1 else { return }
        last = 1
        sink(1)
    }
}
