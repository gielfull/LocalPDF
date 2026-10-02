/// Applies a drag-to-reorder: the shape of SwiftUI's `ReorderDifference` (moved ids plus
/// "insert before this id, or at the end") as a pure function over ids.
nonisolated enum Reorder {
    /// Moves `sources` (kept in their current relative order) to just before `target`,
    /// or to the end when `target` is nil. If `target` is itself being moved, the items
    /// land before the first unmoved item that follows it.
    static func move<ID: Hashable>(_ ids: [ID], sources: [ID], before target: ID?) -> [ID] {
        let moving = Set(sources)
        let moved = ids.filter { moving.contains($0) }
        guard !moved.isEmpty else { return ids }
        var remaining = ids.filter { !moving.contains($0) }

        var insertionIndex = remaining.endIndex
        if let target, let targetIndex = ids.firstIndex(of: target) {
            // First unmoved item at or after the target, in the original order.
            if let anchor = ids[targetIndex...].first(where: { !moving.contains($0) }),
               let index = remaining.firstIndex(of: anchor) {
                insertionIndex = index
            }
        }
        remaining.insert(contentsOf: moved, at: insertionIndex)
        return remaining
    }

    /// Reorders `items` to follow `move(_:sources:before:)` on their ids.
    static func move<Item: Identifiable>(_ items: [Item], sources: [Item.ID], before target: Item.ID?) -> [Item] {
        let order = move(items.map(\.id), sources: sources, before: target)
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return order.compactMap { byID[$0] }
    }
}
