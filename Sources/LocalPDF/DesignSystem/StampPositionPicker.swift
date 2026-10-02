import PDFEngine
import SwiftUI

/// A 3×3 grid for choosing where a stamp sits on the page.
struct StampPositionPicker: View {
    @Binding var selection: StampPosition
    var isEnabled = true

    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(Self.rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { position in
                        cell(position)
                    }
                }
            }
        }
        .padding(6)
        .background(.background.secondary, in: .rect(cornerRadius: 8))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Position")
    }

    private func cell(_ position: StampPosition) -> some View {
        let isSelected = position == selection
        return Button {
            selection = position
        } label: {
            RoundedRectangle(cornerRadius: 3)
                .fill(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                .frame(width: 26, height: 18)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(position.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private static let rows: [[StampPosition]] = [
        [.topLeft, .topCenter, .topRight],
        [.middleLeft, .center, .middleRight],
        [.bottomLeft, .bottomCenter, .bottomRight],
    ]
}

extension StampPosition {
    var title: String {
        switch self {
        case .topLeft: "Top left"
        case .topCenter: "Top center"
        case .topRight: "Top right"
        case .middleLeft: "Middle left"
        case .center: "Center"
        case .middleRight: "Middle right"
        case .bottomLeft: "Bottom left"
        case .bottomCenter: "Bottom center"
        case .bottomRight: "Bottom right"
        }
    }

    /// The matching SwiftUI alignment, for previews drawn over a thumbnail.
    var alignment: Alignment {
        switch self {
        case .topLeft: .topLeading
        case .topCenter: .top
        case .topRight: .topTrailing
        case .middleLeft: .leading
        case .center: .center
        case .middleRight: .trailing
        case .bottomLeft: .bottomLeading
        case .bottomCenter: .bottom
        case .bottomRight: .bottomTrailing
        }
    }
}
