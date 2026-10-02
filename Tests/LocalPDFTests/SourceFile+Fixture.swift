import Foundation
import UniformTypeIdentifiers
@testable import LocalPDF

extension SourceFile {
    /// A file with made-up facts; nothing is read from disk.
    static func fixture(
        _ name: String, kind: Kind = .pdf, megabytes: Double = 1,
        pages: Int = 10, encrypted: Bool = false, locked: Bool = false, scanned: Bool = false
    ) -> SourceFile {
        SourceFile(
            id: UUID(), url: URL(filePath: "/tmp/\(name)"), kind: kind,
            contentType: kind == .pdf ? .pdf : kind == .image ? .png : .plainText,
            byteCount: Int64(megabytes * 1_000_000), pageCount: pages, firstPageSize: nil,
            isEncrypted: encrypted, isLocked: locked, password: nil, looksScanned: scanned
        )
    }
}
