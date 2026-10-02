import Foundation
import PDFKit

/// The one way operations open inputs and write PDFKit documents, so password handling
/// and error mapping are identical across tools.
///
/// The engine never calls `startAccessingSecurityScopedResource`: the app owns sandbox
/// access and keeps it open for the duration of a job.
enum DocumentIO {
    /// Opens `input`, unlocking it with `InputFile.password` when needed.
    ///
    /// - Throws: `.cannotOpen` when the file isn't a readable PDF, `.passwordRequired` when it
    ///   has an open password and none was given, `.wrongPassword` when the given one fails,
    ///   `.unsupportedInput` for a PDF without pages.
    static func open(_ input: InputFile) throws -> PDFDocument {
        guard let document = PDFDocument(url: input.url) else {
            throw PDFEngineError.cannotOpen(input.url)
        }
        let password = input.password.flatMap { $0.isEmpty ? nil : $0 }

        if document.isLocked {
            guard let password else { throw PDFEngineError.passwordRequired(input.url) }
            guard document.unlock(withPassword: password) else {
                throw PDFEngineError.wrongPassword(input.url)
            }
        } else if document.isEncrypted, let password {
            // Permissions-only encryption: an owner password lifts the restrictions. Any other
            // password is irrelevant to opening the file, so a mismatch is not an error.
            _ = document.unlock(withPassword: password)
        }

        guard document.pageCount > 0 else { throw PDFEngineError.unsupportedInput(input.url) }
        return document
    }

    /// The only input of a single-file tool.
    /// - Throws: `.unsupportedInput` naming the first extra file, or a placeholder when empty.
    static func singleInput(_ inputs: [InputFile]) throws -> InputFile {
        guard inputs.count == 1 else {
            throw PDFEngineError.unsupportedInput(inputs.dropFirst().first?.url ?? noInputURL)
        }
        return inputs[0]
    }

    /// Stand-in URL for "no file was given"; `PDFEngineError` cases all carry a URL.
    static let noInputURL = URL(filePath: "No file")

    /// Writes `document` to `url`, mapping failure to `.writeFailed`.
    static func write(_ document: PDFDocument, to url: URL,
                      options: [PDFDocumentWriteOption: Any] = [:]) throws {
        guard document.write(to: url, withOptions: options) else {
            throw PDFEngineError.writeFailed(url)
        }
    }

    /// Size of the file at `url` in bytes, or `nil` when it can't be read. Asks the file
    /// system each time: `URL.resourceValues` caches per URL and goes stale on rewrite.
    static func fileSize(_ url: URL) -> Int? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
        return (attributes?[.size] as? NSNumber)?.intValue
    }

    /// The file name without its extension: "report" for ".../report.pdf".
    static func stem(of url: URL) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        return stem.isEmpty ? "Untitled" : stem
    }
}
