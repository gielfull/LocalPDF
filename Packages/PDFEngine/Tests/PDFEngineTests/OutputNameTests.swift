import Foundation
@testable import PDFEngine
import Testing

@Suite("Output names")
struct OutputNameTests {
    @Test("localpdf_<action>_<original name>.<ext>")
    func basicShape() {
        let url = URL(filePath: "/tmp/Quarterly Report.pdf")
        #expect(OutputName.make(.compress, from: url) == "localpdf_compress_Quarterly Report.pdf")
        #expect(OutputName.make(.pageNumbers, from: url) == "localpdf_page-numbers_Quarterly Report.pdf")
    }

    @Test("A detail tells apart several outputs of one input")
    func detail() {
        let url = URL(filePath: "/tmp/report.pdf")
        #expect(OutputName.make(.split, from: url, detail: "pages-1-3") == "localpdf_split_report_pages-1-3.pdf")
        #expect(OutputName.make(.pdfToImages, from: url, detail: "page-001", extension: "png")
                == "localpdf_pdf-to-images_report_page-001.png")
        #expect(OutputName.make(.extractPages, from: url, detail: nil) == "localpdf_extract-pages_report.pdf")
    }

    @Test("Chaining tools replaces the earlier action instead of stacking prefixes")
    func chained() {
        let earlier = URL(filePath: "/tmp/localpdf_compress_report.pdf")
        #expect(OutputName.make(.protect, from: earlier) == "localpdf_protect_report.pdf")
        let withDetail = URL(filePath: "/tmp/localpdf_split_report_pages-1-3.pdf")
        #expect(OutputName.make(.rotate, from: withDetail) == "localpdf_rotate_report_pages-1-3.pdf")
    }

    @Test("Names that merely start with \"localpdf_\" are left alone")
    func lookalike() {
        let url = URL(filePath: "/tmp/localpdf_notes.pdf")
        #expect(OutputName.make(.merge, from: url) == "localpdf_merge_localpdf_notes.pdf")
        let bare = URL(filePath: "/tmp/localpdf_compress_.pdf")
        #expect(OutputName.make(.merge, from: bare) == "localpdf_merge_localpdf_compress_.pdf")
    }

    @Test("Every tool has a distinct, lower-case, hyphenated action")
    func actions() {
        let actions = ToolID.allCases.map(OutputName.action(for:))
        #expect(Set(actions).count == ToolID.allCases.count)
        for action in actions {
            #expect(action.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" }, "\(action)")
        }
    }
}
