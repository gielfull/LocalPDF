import CoreGraphics
import Foundation

extension CGRect {
    /// The rect wrapped as `CFData`, the form `kCGPDFContextMediaBox`/`CropBox` expect.
    var pdfBoxData: CFData {
        var box = self
        return withUnsafeBytes(of: &box) { Data($0) } as CFData
    }

    /// Page info for `CGContext.beginPDFPage` with this rect as the media box.
    var pdfPageInfo: CFDictionary {
        [kCGPDFContextMediaBox: pdfBoxData] as CFDictionary
    }
}
