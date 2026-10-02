/// Stable identifier for every tool in the app (the iLovePDF-parity tool list).
///
/// The raw values are persisted (saved workflows, App Intents, CLI flags), so never
/// rename a case's raw value once it has shipped. Case order is catalog order, and
/// `ToolCatalog.all` follows it.
public enum ToolID: String, Codable, Sendable, CaseIterable, Hashable {
    // Organize
    case merge, split, removePages, extractPages, organize
    // Optimize
    case compress, repair, ocr
    // Convert to PDF
    case imagesToPDF, wordToPDF, powerPointToPDF, excelToPDF, htmlToPDF
    // Convert from PDF
    case pdfToImages, pdfToWord, pdfToPowerPoint, pdfToExcel, pdfToPDFA, pdfToMarkdown
    // Edit
    case edit, rotate, pageNumbers, watermark, crop, forms
    // Security
    case unlock, protect, sign, redact, compare
    // Intelligence
    case summarize, translate
}
