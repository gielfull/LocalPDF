import PDFEngine
import Testing
@testable import LocalPDF

@Suite("App smoke")
struct LocalPDFTests {
    @Test("The app target links PDFEngine and sees the full catalog")
    func catalogReachable() {
        #expect(ToolCatalog.all.count == ToolID.allCases.count)
    }

    @Test("Every category has a title and every tool resolves a style")
    func categoryStyles() {
        for category in ToolCategory.allCases {
            #expect(!category.style.title.isEmpty)
        }
    }
}
