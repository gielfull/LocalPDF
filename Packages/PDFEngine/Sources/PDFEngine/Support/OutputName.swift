import Foundation

/// Builds every output file name: `localpdf_<action>_<original name>[_<detail>].<ext>`,
/// e.g. "localpdf_compress_report.pdf" or "localpdf_split_report_pages-1-3.pdf".
///
/// The fixed prefix groups LocalPDF's results together in a folder sorted by name, and
/// the action says what was done without opening the file. The original name is kept
/// as-is (spaces and case included) so the user still recognizes it.
enum OutputName {
    static let prefix = "localpdf"

    /// The name for an output of `tool` made from `url`. `detail` tells apart several
    /// outputs of one input ("pages-1-3", "page-001").
    static func make(_ tool: ToolID, from url: URL, detail: String? = nil, extension ext: String = "pdf") -> String {
        var name = "\(prefix)_\(action(for: tool))_\(originalStem(of: url))"
        if let detail, !detail.isEmpty {
            name += "_\(detail)"
        }
        return "\(name).\(ext)"
    }

    /// The input's name without its extension, minus the prefix of an earlier LocalPDF
    /// action. Chaining tools ("Continue with…") then gives "localpdf_protect_report.pdf"
    /// rather than "localpdf_protect_localpdf_compress_report.pdf".
    static func originalStem(of url: URL) -> String {
        let stem = DocumentIO.stem(of: url)
        for tool in ToolID.allCases {
            let earlier = "\(prefix)_\(action(for: tool))_"
            if stem.hasPrefix(earlier), stem.count > earlier.count {
                return String(stem.dropFirst(earlier.count))
            }
        }
        return stem
    }

    /// The `<action>` part: short, lower-case, hyphenated. Spelled out per tool, not derived
    /// from `ToolID`'s raw value, because these appear in users' folders and must not
    /// change if a case is ever renamed.
    static func action(for tool: ToolID) -> String {
        switch tool {
        case .merge: "merge"
        case .split: "split"
        case .removePages: "remove-pages"
        case .extractPages: "extract-pages"
        case .organize: "organize"
        case .compress: "compress"
        case .repair: "repair"
        case .ocr: "ocr"
        case .imagesToPDF: "images-to-pdf"
        case .wordToPDF: "word-to-pdf"
        case .powerPointToPDF: "powerpoint-to-pdf"
        case .excelToPDF: "excel-to-pdf"
        case .htmlToPDF: "html-to-pdf"
        case .pdfToImages: "pdf-to-images"
        case .pdfToWord: "pdf-to-word"
        case .pdfToPowerPoint: "pdf-to-powerpoint"
        case .pdfToExcel: "pdf-to-excel"
        case .pdfToPDFA: "pdf-to-pdfa"
        case .pdfToMarkdown: "pdf-to-markdown"
        case .edit: "edit"
        case .rotate: "rotate"
        case .pageNumbers: "page-numbers"
        case .watermark: "watermark"
        case .crop: "crop"
        case .forms: "forms"
        case .unlock: "unlock"
        case .protect: "protect"
        case .sign: "sign"
        case .redact: "redact"
        case .compare: "compare"
        case .summarize: "summary"
        case .translate: "translate"
        }
    }
}
