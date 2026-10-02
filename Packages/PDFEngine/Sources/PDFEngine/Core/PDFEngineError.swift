import Foundation

/// The errors every operation reports. Messages are short and user-facing; the UI
/// shows `errorDescription` as-is.
public enum PDFEngineError: Error, Sendable, Equatable, LocalizedError {
    case cannotOpen(URL)
    case passwordRequired(URL)
    case wrongPassword(URL)
    /// The offending part of the user's page-range text.
    case invalidPageRange(String)
    case writeFailed(URL)
    case unsupportedInput(URL)
    case cancelled
    case notImplemented(ToolID)
    /// On-device text recognition (OCR) failed for this file.
    case recognitionFailed(URL)

    public var errorDescription: String? {
        switch self {
        case .cannotOpen(let url):
            "Couldn't open \u{201C}\(url.lastPathComponent)\u{201D}."
        case .passwordRequired(let url):
            "\u{201C}\(url.lastPathComponent)\u{201D} is password protected."
        case .wrongPassword(let url):
            "The password for \u{201C}\(url.lastPathComponent)\u{201D} is incorrect."
        case .invalidPageRange(let text):
            "\u{201C}\(text)\u{201D} isn't a valid page range."
        case .writeFailed(let url):
            "Couldn't save \u{201C}\(url.lastPathComponent)\u{201D}."
        case .unsupportedInput(let url):
            "\u{201C}\(url.lastPathComponent)\u{201D} isn't a supported file type for this tool."
        case .cancelled:
            "The task was cancelled."
        case .notImplemented(let tool):
            "\(ToolCatalog.descriptor(for: tool).title) isn't available yet."
        case .recognitionFailed(let url):
            "Couldn't recognize the text in \u{201C}\(url.lastPathComponent)\u{201D}."
        }
    }
}
