import Foundation

/// Compress's structural pass, with qpdf: lossless savings in how the file is stored.
///
/// - Objects are packed into compressed object streams (most of a text-heavy file's
///   overhead is thousands of small uncompressed dictionaries) with a compact xref stream.
/// - Every Flate stream is decoded and re-encoded at zlib level 9.
/// - Byte-identical streams (an image or font repeated in every merged file) become one.
/// - Resources no page uses, and objects nothing refers to, are left out.
/// - `.extreme` also drops page thumbnails, XMP metadata and application-private data.
///
/// Nothing visible changes: pages, text, images, links, bookmarks and forms stay.
enum StructureOptimizer {
    /// Writes an optimized copy of `pdf` to `output`. Modifies `pdf`; open a fresh one per pass.
    static func optimize(_ pdf: QPDF, to output: URL, level: CompressOperation.Level,
                         encryption: QPDF.Encryption) throws(QPDF.Failure) {
        if level == .extreme {
            pdf.removeThumbnails()
            pdf.removeMetadata()
        }
        try pdf.removeUnreferencedResources()
        try pdf.deduplicateStreams()

        var options = QPDF.WriteOptions()
        options.generateObjectStreams = true
        options.recompressFlate = true
        options.encryption = encryption
        try pdf.write(to: output, options)
    }
}
