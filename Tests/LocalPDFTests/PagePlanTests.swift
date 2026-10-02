import Testing
@testable import LocalPDF

@Suite("Organize page plan")
struct PagePlanTests {
    @Test("A fresh plan is the document as-is")
    func initial() {
        let plan = PagePlan(pageCount: 3)
        #expect(plan.instructions.map(\.sourcePageIndex) == [0, 1, 2])
        #expect(!plan.isModified)
    }

    @Test("Click, ⌘-click and ⇧-click select like Finder")
    func selection() {
        var plan = PagePlan(pageCount: 6)
        let ids = plan.pages.map(\.id)
        plan.click(ids[1], modifier: .none)
        #expect(plan.selection == [ids[1]])
        plan.click(ids[4], modifier: .shift)
        #expect(plan.selection == Set(ids[1...4]))
        plan.click(ids[2], modifier: .command)
        #expect(plan.selection == [ids[1], ids[3], ids[4]])
        plan.click(ids[0], modifier: .none)
        #expect(plan.selection == [ids[0]])
    }

    @Test("Rotation wraps both ways")
    func rotate() {
        var plan = PagePlan(pageCount: 2)
        plan.click(plan.pages[0].id, modifier: .none)
        plan.rotateSelection(by: -90)
        #expect(plan.pages[0].rotation == 270)
        plan.rotateSelection(by: 90)
        plan.rotateSelection(by: 90)
        #expect(plan.instructions[0].additionalRotation == 90)
        #expect(plan.isModified)
    }

    @Test("Delete removes the selection and selects the page that slid in")
    func delete() {
        var plan = PagePlan(pageCount: 4)
        plan.click(plan.pages[1].id, modifier: .none)
        plan.click(plan.pages[2].id, modifier: .command)
        let next = plan.pages[3].id
        plan.deleteSelection()
        #expect(plan.instructions.map(\.sourcePageIndex) == [0, 3])
        #expect(plan.selection == [next])
    }

    @Test("Duplicate inserts copies right after their originals")
    func duplicate() {
        var plan = PagePlan(pageCount: 3)
        plan.click(plan.pages[0].id, modifier: .none)
        plan.click(plan.pages[2].id, modifier: .command)
        plan.duplicateSelection()
        #expect(plan.instructions.map(\.sourcePageIndex) == [0, 0, 1, 2, 2])
        #expect(plan.selection.count == 2)
    }

    @Test("A blank page goes after the selection, or at the end")
    func insertBlank() {
        var plan = PagePlan(pageCount: 2)
        plan.insertBlankAfterSelection()
        #expect(plan.instructions.map(\.sourcePageIndex) == [0, 1, nil])
        plan.click(plan.pages[0].id, modifier: .none)
        plan.insertBlankAfterSelection()
        #expect(plan.instructions.map(\.sourcePageIndex) == [0, nil, 1, nil])
    }

    @Test("Moving pages follows the reorder difference")
    func move() {
        var plan = PagePlan(pageCount: 4)
        let ids = plan.pages.map(\.id)
        plan.move([ids[3]], before: ids[0])
        #expect(plan.instructions.map(\.sourcePageIndex) == [3, 0, 1, 2])
        plan.move([ids[3], ids[0]], before: nil)
        #expect(plan.instructions.map(\.sourcePageIndex) == [1, 2, 3, 0])
    }

    @Test("Reset restores the untouched document")
    func reset() {
        var plan = PagePlan(pageCount: 3)
        plan.selectAll()
        plan.deleteSelection()
        plan.reset()
        #expect(plan.instructions.map(\.sourcePageIndex) == [0, 1, 2])
        #expect(!plan.isModified)
    }
}
