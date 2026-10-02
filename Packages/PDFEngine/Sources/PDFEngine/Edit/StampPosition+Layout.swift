import CoreGraphics

extension StampPosition {
    /// Bottom-left corner of a box of `size` placed at this position in `container`,
    /// `margin` points from the edges it is aligned to.
    func origin(for size: CGSize, in container: CGSize, margin: CGFloat) -> CGPoint {
        let x: CGFloat = switch self {
        case .topLeft, .middleLeft, .bottomLeft: margin
        case .topCenter, .center, .bottomCenter: (container.width - size.width) / 2
        case .topRight, .middleRight, .bottomRight: container.width - margin - size.width
        }
        let y: CGFloat = switch self {
        case .bottomLeft, .bottomCenter, .bottomRight: margin
        case .middleLeft, .center, .middleRight: (container.height - size.height) / 2
        case .topLeft, .topCenter, .topRight: container.height - margin - size.height
        }
        return CGPoint(x: x, y: y)
    }
}
