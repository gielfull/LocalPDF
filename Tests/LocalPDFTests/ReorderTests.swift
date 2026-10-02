import Testing
@testable import LocalPDF

@Suite("Reorder")
struct ReorderTests {
    @Test("Move one item before another, or to the end")
    func single() {
        #expect(Reorder.move(["a", "b", "c", "d"], sources: ["d"], before: "b") == ["a", "d", "b", "c"])
        #expect(Reorder.move(["a", "b", "c"], sources: ["a"], before: nil) == ["b", "c", "a"])
    }

    @Test("Several items keep their relative order")
    func several() {
        #expect(Reorder.move(["a", "b", "c", "d", "e"], sources: ["e", "b"], before: "a") == ["b", "e", "a", "c", "d"])
    }

    @Test("Dropping onto a moved item lands before the next unmoved one")
    func targetIsMoving() {
        #expect(Reorder.move(["a", "b", "c", "d"], sources: ["b", "c"], before: "b") == ["a", "b", "c", "d"])
        #expect(Reorder.move(["a", "b", "c"], sources: ["c"], before: "c") == ["a", "b", "c"])
    }

    @Test("Unknown sources change nothing")
    func unknown() {
        #expect(Reorder.move(["a", "b"], sources: ["z"], before: "a") == ["a", "b"])
    }
}
