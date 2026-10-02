import Testing
import UniformTypeIdentifiers
@testable import PDFEngine

@Suite("ToolCatalog")
struct ToolCatalogTests {
    @Test("Every ToolID has exactly one descriptor")
    func everyToolHasExactlyOneDescriptor() {
        for id in ToolID.allCases {
            #expect(ToolCatalog.all.count(where: { $0.id == id }) == 1, "\(id)")
        }
        #expect(ToolCatalog.all.count == ToolID.allCases.count)
    }

    @Test("Catalog order is ToolID declaration order")
    func order() {
        #expect(ToolCatalog.all.map(\.id) == ToolID.allCases)
    }

    @Test("descriptor(for:) returns the matching descriptor", arguments: ToolID.allCases)
    func lookup(id: ToolID) {
        #expect(ToolCatalog.descriptor(for: id).id == id)
    }

    @Test("Categories partition the catalog, and none is empty")
    func categoriesPartition() {
        let grouped = ToolCategory.allCases.flatMap { ToolCatalog.tools(in: $0) }
        #expect(Set(grouped.map(\.id)) == Set(ToolID.allCases))
        #expect(grouped.count == ToolID.allCases.count)
        for category in ToolCategory.allCases {
            #expect(!ToolCatalog.tools(in: category).isEmpty, "\(category)")
        }
    }

    @Test("Descriptors are fully populated", arguments: ToolID.allCases)
    func populated(id: ToolID) {
        let descriptor = ToolCatalog.descriptor(for: id)
        #expect(!descriptor.title.isEmpty)
        #expect(!descriptor.summary.isEmpty)
        #expect(!descriptor.systemImage.isEmpty)
        #expect(!descriptor.acceptedInputs.isEmpty)
    }

    @Test("Titles are unique")
    func uniqueTitles() {
        #expect(Set(ToolCatalog.all.map(\.title)).count == ToolCatalog.all.count)
    }

    @Test("Exactly the implemented tools are available")
    func availability() {
        let available: Set<ToolID> = [
            .merge, .split, .removePages, .extractPages, .organize,
            .compress, .imagesToPDF, .pdfToImages,
            .rotate, .pageNumbers, .watermark, .crop,
            .unlock, .protect,
            .ocr,
            .repair,
        ]
        #expect(Set(ToolCatalog.all.filter(\.isAvailable).map(\.id)) == available)
    }

    @Test("Office inputs resolve to real system types")
    func officeTypes() {
        let docx = UTType(filenameExtension: "docx")
        #expect(docx != nil)
        #expect(ToolCatalog.descriptor(for: .wordToPDF).acceptedInputs.contains(docx!))
    }
}
