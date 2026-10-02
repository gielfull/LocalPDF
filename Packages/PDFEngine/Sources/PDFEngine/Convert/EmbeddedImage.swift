import CoreGraphics
import Foundation
import ImageIO

/// An image XObject's pixels, decoded as far as the engine can without a full PDF
/// interpreter. Best effort: what can't be decoded is skipped by the caller.
enum EmbeddedImage {
    /// A DCTDecode stream: the original JPEG bytes, writable as-is.
    case jpeg(Data)
    /// Anything else, decoded to pixels.
    case bitmap(CGImage)

    /// Decodes `stream`, or returns `nil` for stencil masks and encodings/color spaces that
    /// aren't supported (DeviceN, Separation, Lab, CCITT/JBIG2 masks, …). Soft masks are
    /// ignored, so transparent images come out opaque.
    init?(stream: CGPDFStreamRef) {
        guard let dictionary = CGPDFStreamGetDictionary(stream) else { return nil }
        var isMask: CGPDFBoolean = 0
        if CGPDFDictionaryGetBoolean(dictionary, "ImageMask", &isMask), isMask != 0 { return nil }

        var format = CGPDFDataFormat.raw
        guard let data = CGPDFStreamCopyData(stream, &format) as Data?, !data.isEmpty else { return nil }

        switch format {
        case .jpegEncoded:
            self = .jpeg(data)
        case .JPEG2000:
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { return nil }
            self = .bitmap(image)
        case .raw:
            guard let image = Self.bitmap(from: data, dictionary: dictionary) else { return nil }
            self = .bitmap(image)
        @unknown default:
            return nil
        }
    }

    /// The pixels as a `CGImage`; for JPEG bytes this decodes them.
    var cgImage: CGImage? {
        switch self {
        case .bitmap(let image):
            return image
        case .jpeg(let data):
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
    }

    // MARK: - Raw samples

    /// Builds a `CGImage` from decoded (unfiltered) samples, per PDF 32000 §8.9.
    private static func bitmap(from data: Data, dictionary: CGPDFDictionaryRef) -> CGImage? {
        var width: CGPDFInteger = 0
        var height: CGPDFInteger = 0
        guard CGPDFDictionaryGetInteger(dictionary, "Width", &width),
              CGPDFDictionaryGetInteger(dictionary, "Height", &height),
              width > 0, height > 0
        else { return nil }

        var bitsPerComponent: CGPDFInteger = 8
        _ = CGPDFDictionaryGetInteger(dictionary, "BitsPerComponent", &bitsPerComponent)
        guard [1, 2, 4, 8, 16].contains(bitsPerComponent) else { return nil }

        var colorSpaceObject: CGPDFObjectRef?
        guard CGPDFDictionaryGetObject(dictionary, "ColorSpace", &colorSpaceObject),
              let colorSpaceObject,
              let space = colorSpace(from: colorSpaceObject)
        else { return nil }

        let components = space.model == .indexed ? 1 : space.numberOfComponents
        let bitsPerPixel = bitsPerComponent * components
        let bytesPerRow = (width * bitsPerPixel + 7) / 8
        guard data.count >= bytesPerRow * height,
              let provider = CGDataProvider(data: data as CFData)
        else { return nil }

        var bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        if bitsPerComponent == 16 { bitmapInfo.insert(.byteOrder16Big) } // PDF samples are big-endian.

        return CGImage(
            width: width, height: height,
            bitsPerComponent: bitsPerComponent, bitsPerPixel: bitsPerPixel, bytesPerRow: bytesPerRow,
            space: space, bitmapInfo: bitmapInfo, provider: provider,
            decode: decodeArray(in: dictionary, components: components),
            shouldInterpolate: false, intent: .defaultIntent
        )
    }

    /// `/Decode`, when present and the right length (e.g. `[1 0]` for inverted gray).
    private static func decodeArray(in dictionary: CGPDFDictionaryRef, components: Int) -> [CGFloat]? {
        var array: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dictionary, "Decode", &array), let array,
              CGPDFArrayGetCount(array) == components * 2
        else { return nil }
        var values: [CGFloat] = []
        for index in 0..<CGPDFArrayGetCount(array) {
            var value: CGPDFReal = 0
            guard CGPDFArrayGetNumber(array, index, &value) else { return nil }
            values.append(value)
        }
        return values
    }

    /// The color spaces a raw image can use here: Device*, Cal*, ICCBased and Indexed.
    private static func colorSpace(from object: CGPDFObjectRef, depth: Int = 0) -> CGColorSpace? {
        guard depth < 4 else { return nil }
        var name: UnsafePointer<CChar>?
        if CGPDFObjectGetValue(object, .name, &name), let name {
            return deviceSpace(named: String(cString: name))
        }

        var array: CGPDFArrayRef?
        guard CGPDFObjectGetValue(object, .array, &array), let array else { return nil }
        var family: UnsafePointer<CChar>?
        guard CGPDFArrayGetName(array, 0, &family), let family else { return nil }

        switch String(cString: family) {
        case "ICCBased":
            var profile: CGPDFStreamRef?
            guard CGPDFArrayGetStream(array, 1, &profile), let profile,
                  let profileDictionary = CGPDFStreamGetDictionary(profile)
            else { return nil }
            var format = CGPDFDataFormat.raw
            if let data = CGPDFStreamCopyData(profile, &format),
               let space = CGColorSpace(iccData: data) {
                return space
            }
            var componentCount: CGPDFInteger = 0
            _ = CGPDFDictionaryGetInteger(profileDictionary, "N", &componentCount)
            return switch componentCount {
            case 1: CGColorSpaceCreateDeviceGray()
            case 3: CGColorSpaceCreateDeviceRGB()
            case 4: CGColorSpaceCreateDeviceCMYK()
            default: nil
            }
        case "CalRGB":
            return CGColorSpaceCreateDeviceRGB()
        case "CalGray":
            return CGColorSpaceCreateDeviceGray()
        case "Indexed", "I":
            return indexedSpace(from: array, depth: depth)
        default:
            return deviceSpace(named: String(cString: family))
        }
    }

    private static func deviceSpace(named name: String) -> CGColorSpace? {
        switch name {
        case "DeviceRGB", "RGB": CGColorSpaceCreateDeviceRGB()
        case "DeviceGray", "G": CGColorSpaceCreateDeviceGray()
        case "DeviceCMYK", "CMYK": CGColorSpaceCreateDeviceCMYK()
        default: nil
        }
    }

    /// `[/Indexed base hival lookup]`, with the lookup table as a string or a stream.
    private static func indexedSpace(from array: CGPDFArrayRef, depth: Int) -> CGColorSpace? {
        var baseObject: CGPDFObjectRef?
        var highest: CGPDFInteger = 0
        guard CGPDFArrayGetCount(array) == 4,
              CGPDFArrayGetObject(array, 1, &baseObject), let baseObject,
              let base = colorSpace(from: baseObject, depth: depth + 1),
              CGPDFArrayGetInteger(array, 2, &highest), (0...255).contains(highest)
        else { return nil }

        var table: Data?
        var string: CGPDFStringRef?
        var stream: CGPDFStreamRef?
        if CGPDFArrayGetString(array, 3, &string), let string,
           let bytes = CGPDFStringGetBytePtr(string) {
            table = Data(bytes: bytes, count: CGPDFStringGetLength(string))
        } else if CGPDFArrayGetStream(array, 3, &stream), let stream {
            var format = CGPDFDataFormat.raw
            table = CGPDFStreamCopyData(stream, &format) as Data?
        }
        let needed = (highest + 1) * base.numberOfComponents
        guard let table, table.count >= needed else { return nil }
        return table.withUnsafeBytes { buffer in
            guard let colorTable = buffer.bindMemory(to: UInt8.self).baseAddress else { return nil }
            return CGColorSpace(indexedBaseSpace: base, last: highest, colorTable: colorTable)
        }
    }
}
