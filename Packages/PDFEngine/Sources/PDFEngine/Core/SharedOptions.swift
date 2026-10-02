import Foundation

/// Where a stamp (page number, watermark) sits on the page. Positions are relative
/// to the page's crop box after rotation, i.e. as the reader sees the page.
public enum StampPosition: String, Codable, Sendable, Hashable, CaseIterable {
    case topLeft, topCenter, topRight
    case middleLeft, center, middleRight
    case bottomLeft, bottomCenter, bottomRight
}

/// An sRGB color as plain data, so options stay Codable and UI-free.
public struct RGBAColor: Codable, Sendable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let black = RGBAColor(red: 0, green: 0, blue: 0)
    public static let red = RGBAColor(red: 0.85, green: 0.1, blue: 0.1)
    public static let gray = RGBAColor(red: 0.5, green: 0.5, blue: 0.5)
}

/// Which pages an option applies to. `text` uses `PageRange` syntax ("1-3, 5, 8-");
/// `nil` means every page.
public typealias PageSelection = String?
