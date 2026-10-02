import CoreGraphics
import Foundation

/// Finds the image XObjects a page draws, by walking its resources with CGPDF.
enum PDFImageXObjects {
    /// Every image XObject reachable from `page`'s resources, including those nested in
    /// form XObjects, in resource-name order. Streams already in `seen` are skipped and
    /// new ones are added, so an image shared by many pages is reported once per document.
    static func images(on page: CGPDFPage, seen: inout Set<CGPDFStreamRef>) -> [CGPDFStreamRef] {
        guard let resources = resources(of: page) else { return [] }
        var result: [CGPDFStreamRef] = []
        var visitedForms = Set<CGPDFStreamRef>()
        collect(from: resources, into: &result, seen: &seen, visitedForms: &visitedForms)
        return result
    }

    /// Bytes the page's images occupy in the file (their encoded stream lengths).
    static func encodedSize(of page: CGPDFPage) -> Int {
        var seen = Set<CGPDFStreamRef>()
        return images(on: page, seen: &seen).reduce(0) { total, stream in
            total + encodedLength(of: stream)
        }
    }

    /// The stream's `/Length`, or its decoded size when the length isn't a plain integer.
    static func encodedLength(of stream: CGPDFStreamRef) -> Int {
        if let dictionary = CGPDFStreamGetDictionary(stream) {
            var length: CGPDFInteger = 0
            if CGPDFDictionaryGetInteger(dictionary, "Length", &length), length > 0 {
                return length
            }
        }
        var format = CGPDFDataFormat.raw
        return (CGPDFStreamCopyData(stream, &format) as Data?)?.count ?? 0
    }

    // MARK: - Private

    /// `/Resources`, inherited from the page tree when the page doesn't carry its own.
    private static func resources(of page: CGPDFPage) -> CGPDFDictionaryRef? {
        var node = page.dictionary
        var depth = 0
        while let current = node, depth < 64 {
            var resources: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(current, "Resources", &resources), let resources {
                return resources
            }
            var parent: CGPDFDictionaryRef?
            node = CGPDFDictionaryGetDictionary(current, "Parent", &parent) ? parent : nil
            depth += 1
        }
        return nil
    }

    private static func collect(
        from resources: CGPDFDictionaryRef,
        into result: inout [CGPDFStreamRef],
        seen: inout Set<CGPDFStreamRef>,
        visitedForms: inout Set<CGPDFStreamRef>
    ) {
        var xObjects: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(resources, "XObject", &xObjects), let xObjects else { return }

        for (_, stream) in namedStreams(in: xObjects) {
            guard let dictionary = CGPDFStreamGetDictionary(stream) else { continue }
            switch name(for: "Subtype", in: dictionary) {
            case "Image":
                if seen.insert(stream).inserted { result.append(stream) }
            case "Form":
                guard visitedForms.insert(stream).inserted else { continue }
                var formResources: CGPDFDictionaryRef?
                if CGPDFDictionaryGetDictionary(dictionary, "Resources", &formResources), let formResources {
                    collect(from: formResources, into: &result, seen: &seen, visitedForms: &visitedForms)
                }
            default:
                continue
            }
        }
    }

    /// The dictionary's stream values, sorted by key so output order is stable.
    private static func namedStreams(in dictionary: CGPDFDictionaryRef) -> [(String, CGPDFStreamRef)] {
        var entries: [(String, CGPDFStreamRef)] = []
        withUnsafeMutablePointer(to: &entries) { pointer in
            CGPDFDictionaryApplyFunction(dictionary, { key, object, info in
                var stream: CGPDFStreamRef?
                guard let info, CGPDFObjectGetValue(object, .stream, &stream), let stream else { return }
                info.assumingMemoryBound(to: [(String, CGPDFStreamRef)].self)
                    .pointee.append((String(cString: key), stream))
            }, pointer)
        }
        return entries.sorted { $0.0.localizedStandardCompare($1.0) == .orderedAscending }
    }

    static func name(for key: String, in dictionary: CGPDFDictionaryRef) -> String? {
        var value: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(dictionary, key, &value), let value else { return nil }
        return String(cString: value)
    }
}
