import CoreGraphics
import Foundation
import PDFKit

extension QPDF.Encryption {
    /// The encryption that gives a rebuilt copy of `input` the same protection as `source`
    /// (the opened input): same open password, same permission flags, as AES-256. The owner
    /// password can't be recovered, so the copy gets a random one; Unlock still lifts the
    /// restrictions for anyone who can open the file.
    ///
    /// Nil when the protection can't be reproduced, and the caller must not re-encrypt:
    /// - `source` was opened with owner rights. PDFKit then reports every permission, and
    ///   the password typed is the owner's, which would become the new open password: the
    ///   holders of the real open password would be locked out and the restrictions lost.
    /// - The file needs an open password but none was given.
    ///
    /// Callers keep the original encryption with `.keep` (qpdf reuses the file's own key and
    /// passwords) instead.
    static func matching(_ source: PDFDocument, input: InputFile) -> QPDF.Encryption? {
        guard source.isEncrypted else { return .remove }
        guard source.permissionsStatus != .owner else { return nil }
        let password = input.password ?? ""
        // `source` is unlocked by now; ask the file whether opening it takes a password. When
        // CoreGraphics can't tell (it can't parse the file), assume it does if one was given.
        let needsOpenPassword = CGPDFDocument(input.url as CFURL).map { !$0.isUnlocked } ?? !password.isEmpty
        if needsOpenPassword, password.isEmpty { return nil }
        return .aes256(userPassword: needsOpenPassword ? password : "", ownerPassword: UUID().uuidString,
                       permissions: source.accessPermissions.rawValue)
    }
}
