/// A rendered pixel, coarsely classified so JPEG noise doesn't matter.
struct Swatch: Equatable, CustomStringConvertible {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    enum Name: String { case red, green, blue, white, black, other }

    var name: Name {
        switch (red > 180, green > 180, blue > 180, red < 70, green < 70, blue < 70) {
        case (true, _, _, _, true, true): .red
        case (_, true, _, true, _, true): .green
        case (_, _, true, true, true, _): .blue
        case (true, true, true, _, _, _): .white
        case (_, _, _, true, true, true): .black
        default: .other
        }
    }

    var description: String { "\(name) (\(red), \(green), \(blue))" }
}
