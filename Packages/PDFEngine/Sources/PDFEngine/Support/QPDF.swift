import CQPDF
import Foundation
import PDFKit

/// A PDF opened with qpdf (vendored in the `CQPDF` target), through its C API.
///
/// qpdf does what PDFKit can't: rebuild a damaged file's cross-reference table, write object
/// streams, recompress and deduplicate streams, and encrypt with AES-256. Reading is lazy, so
/// opening is cheap; problems in the file's body may only surface on `write`.
///
/// Deliberately not `Sendable`: it owns a C handle that must not be used from two threads.
/// Create, use and drop a `QPDF` inside one operation's `run`. Separate instances are
/// independent, so concurrent jobs are fine.
final class QPDF {
    /// A qpdf error, mapped to a `PDFEngineError` by the operation that knows the context.
    struct Failure: Error, CustomStringConvertible {
        let code: qpdf_error_code_e
        let message: String

        var description: String { message }

        var isPasswordError: Bool { code == qpdf_e_password }
    }

    /// How `write(to:_:)` treats encryption.
    enum Encryption {
        /// Same encryption as the input (qpdf's default): same passwords, same key.
        case keep
        /// Writes an unencrypted file.
        case remove
        /// AES-256 (PDF 2.0 / ISO 32000-2 standard security handler, revision 6). An empty
        /// `userPassword` opens without a password but still enforces `permissions`, a mask
        /// of `PDFAccessPermissions` raw values (PDFKit imports those as single cases).
        case aes256(userPassword: String, ownerPassword: String, permissions: UInt)
    }

    struct WriteOptions {
        /// Packs objects into compressed object streams (PDF 1.5+), the biggest structural saving.
        var generateObjectStreams = false
        /// Decodes and re-encodes streams that are already Flate-compressed. Everything qpdf
        /// compresses uses zlib level 9.
        var recompressFlate = false
        var encryption: Encryption = .keep
    }

    /// The encryption dictionary's algorithm, as stored in the file.
    struct EncryptionInfo: Equatable {
        /// `/V`: 5 is AES-256.
        let version: Int
        /// `/R`: 6 is the PDF 2.0 revision of AES-256.
        let revision: Int
        /// The standard crypt filter's `/CFM`, e.g. "/AESV3" for AES-256; nil for V < 4.
        let method: String?
    }

    private var handle: qpdf_data?

    /// Opens `url`, rebuilding the cross-reference table if it is damaged.
    /// - Parameter password: the user or owner password; nil or empty for none.
    /// - Throws: `Failure`, with `isPasswordError` when the password is missing or wrong.
    init(url: URL, password: String? = nil) throws(Failure) {
        handle = qpdf_init()
        // Report errors through return codes only; never print to stderr.
        qpdf_silence_errors(handle)
        qpdf_set_suppress_warnings(handle, QPDF_TRUE)
        qpdf_set_attempt_recovery(handle, QPDF_TRUE)
        let password = password.flatMap { $0.isEmpty ? nil : $0 }
        let status = url.withUnsafeFileSystemRepresentation { path in
            password.withOptionalCString { qpdf_read(handle, path, $0) }
        }
        do {
            try check(status)
        } catch {
            // Freed here rather than left to deinit, so the handle can't leak however Swift
            // treats an initializer that throws.
            qpdf_cleanup(&handle)
            throw error
        }
    }

    deinit {
        // qpdf_cleanup dereferences its argument, and the handle is nil after a failed init.
        if handle != nil { qpdf_cleanup(&handle) }
    }

    var pageCount: Int {
        Int(max(qpdf_get_num_pages(handle), 0))
    }

    var isEncrypted: Bool {
        qpdf_is_encrypted(handle) != QPDF_FALSE
    }

    /// The trailer's `/Encrypt` algorithm, or nil for an unencrypted file.
    var encryption: EncryptionInfo? {
        defer { qpdf_oh_release_all(handle) }
        let encrypt = qpdf_oh_get_key(handle, qpdf_get_trailer(handle), "/Encrypt")
        guard qpdf_oh_is_dictionary(handle, encrypt) != QPDF_FALSE else { return nil }
        let filter = qpdf_oh_get_key(handle, qpdf_oh_get_key(handle, encrypt, "/CF"), "/StdCF")
        let method = qpdf_oh_get_key(handle, filter, "/CFM")
        return EncryptionInfo(
            version: Int(qpdf_oh_get_int_value_as_int(handle, qpdf_oh_get_key(handle, encrypt, "/V"))),
            revision: Int(qpdf_oh_get_int_value_as_int(handle, qpdf_oh_get_key(handle, encrypt, "/R"))),
            method: qpdf_oh_is_name(handle, method) != QPDF_FALSE
                ? String(cString: qpdf_oh_get_name(handle, method)) : nil
        )
    }

    // MARK: - Cleanup passes (call before `write`)

    /// Drops each page's embedded thumbnail image (`/Thumb`); viewers render their own.
    func removeThumbnails() {
        defer { qpdf_oh_release_all(handle) }
        for index in 0..<pageCount {
            qpdf_oh_remove_key(handle, qpdf_get_page_n(handle, index), "/Thumb")
        }
    }

    /// Drops XMP metadata streams and application-private data (`/PieceInfo`, e.g. an
    /// Illustrator editing copy) from the catalog and the pages. The document info
    /// dictionary (title, author) stays.
    func removeMetadata() {
        defer { qpdf_oh_release_all(handle) }
        let owners = [qpdf_get_root(handle)] + (0..<pageCount).map { qpdf_get_page_n(handle, $0) }
        for owner in owners {
            qpdf_oh_remove_key(handle, owner, "/Metadata")
            qpdf_oh_remove_key(handle, owner, "/PieceInfo")
        }
    }

    /// Drops fonts, images and other resources no page uses, when pages share resources.
    func removeUnreferencedResources() throws(Failure) {
        try check(lpdf_qpdf_remove_unreferenced_resources(handle))
    }

    /// Points every use of a byte-identical stream at one copy; returns how many copies went.
    @discardableResult
    func deduplicateStreams() throws(Failure) -> Int {
        var merged: Int32 = 0
        try check(lpdf_qpdf_deduplicate_streams(handle, &merged))
        return Int(merged)
    }

    // MARK: - Writing

    /// Writes the document to `url`. Objects nothing refers to any more are left out.
    func write(to url: URL, _ options: WriteOptions = WriteOptions()) throws(Failure) {
        // Every write goes through this, not only recompressing ones: the level is a global
        // that qpdf reads while writing, and the call_once inside orders that read after the
        // one write to it, whichever thread a job runs on.
        lpdf_qpdf_use_max_flate_level()
        ensureTrailerSize()
        let status = url.withUnsafeFileSystemRepresentation { path -> QPDF_ERROR_CODE in
            let initialized = qpdf_init_write(handle, path)
            guard initialized & Self.errorsBit == 0 else { return initialized }
            qpdf_set_object_stream_mode(handle, options.generateObjectStreams ? qpdf_o_generate : qpdf_o_preserve)
            qpdf_set_compress_streams(handle, QPDF_TRUE)
            qpdf_set_decode_level(handle, qpdf_dl_generalized)
            lpdf_qpdf_set_recompress_flate(handle, options.recompressFlate ? QPDF_TRUE : QPDF_FALSE)
            switch options.encryption {
            case .keep:
                qpdf_set_preserve_encryption(handle, QPDF_TRUE)
            case .remove:
                qpdf_set_preserve_encryption(handle, QPDF_FALSE)
            case .aes256(let user, let owner, let permissions):
                qpdf_set_preserve_encryption(handle, QPDF_FALSE)
                Self.setAES256(handle, user: user, owner: owner, permissions: permissions)
            }
            return qpdf_write(handle)
        }
        try check(status)
    }

    // MARK: - Private

    /// `QPDF_ERRORS` (a `1 << 1` macro, which Swift doesn't import).
    private static let errorsBit: QPDF_ERROR_CODE = 1 << 1

    private static func setAES256(_ handle: qpdf_data?, user: String, owner: String, permissions: UInt) {
        func allows(_ permission: PDFAccessPermissions) -> Bool { permissions & permission.rawValue != 0 }
        func flag(_ permission: PDFAccessPermissions) -> QPDF_BOOL { allows(permission) ? QPDF_TRUE : QPDF_FALSE }
        let print: qpdf_r3_print_e = allows(.allowsHighQualityPrinting) ? qpdf_r3p_full
            : allows(.allowsLowQualityPrinting) ? qpdf_r3p_low : qpdf_r3p_none
        qpdf_set_r6_encryption_parameters2(
            handle, user, owner,
            flag(.allowsContentAccessibility),
            flag(.allowsContentCopying),
            flag(.allowsDocumentAssembly),
            flag(.allowsCommenting),
            flag(.allowsFormFieldEntry),
            flag(.allowsDocumentChanges),
            print,
            QPDF_TRUE // encrypt the XMP metadata too
        )
    }

    /// When the file's trailer is lost, qpdf's recovery makes a new one holding only `/Root`,
    /// and its writer only fills in `/Size` (required; PDFKit won't open a file without it)
    /// when the key exists. A placeholder makes the writer put in the real value.
    private func ensureTrailerSize() {
        defer { qpdf_oh_release_all(handle) }
        let trailer = qpdf_get_trailer(handle)
        if qpdf_oh_has_key(handle, trailer, "/Size") == QPDF_FALSE {
            qpdf_oh_replace_key(handle, trailer, "/Size", qpdf_oh_new_integer(handle, 0))
        }
    }

    /// Throws the pending error when `status` reports one; warnings (recoverable damage) pass.
    private func check(_ status: QPDF_ERROR_CODE) throws(Failure) {
        guard status & Self.errorsBit != 0 || qpdf_has_error(handle) != QPDF_FALSE else { return }
        guard let error = qpdf_get_error(handle) else {
            throw Failure(code: qpdf_e_internal, message: "qpdf reported an error without details")
        }
        throw Failure(code: qpdf_get_error_code(handle, error),
                      message: String(cString: qpdf_get_error_full_text(handle, error)))
    }
}

private extension Optional where Wrapped == String {
    /// Calls `body` with a C string for a value, or with nil.
    func withOptionalCString<Result>(_ body: (UnsafePointer<CChar>?) -> Result) -> Result {
        switch self {
        case .some(let string): string.withCString { body($0) }
        case .none: body(nil)
        }
    }
}
