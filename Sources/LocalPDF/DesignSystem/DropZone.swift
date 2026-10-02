import SwiftUI

/// The large glass drop target for files. It accepts file URLs dragged from Finder and
/// offers an "Add Files" button for the open panel; `accessory` sits below the button
/// (e.g. the staged files and their suggestions).
struct DropZone<Accessory: View>: View {
    let title: String
    let subtitle: String
    let onDrop: ([URL]) -> Void
    let onAdd: () -> Void
    @ViewBuilder var accessory: Accessory

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: isTargeted ? "arrow.down.doc.fill" : "arrow.down.doc")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(isTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .symbolEffect(.bounce, value: isTargeted)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Add Files…", systemImage: "plus", action: onAdd)
                .buttonStyle(.glass)
                .controlSize(.large)
            accessory
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 220)
        .overlay {
            RoundedRectangle(cornerRadius: Self.radius)
                .strokeBorder(
                    isTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [7, 5])
                )
                .padding(6)
        }
        .glassEffect(.regular.tint(isTargeted ? .accentColor.opacity(0.18) : nil), in: .rect(cornerRadius: Self.radius))
        .animation(.snappy(duration: 0.2), value: isTargeted)
        .dropDestination(for: URL.self) { urls, _ in
            onDrop(urls.filter(\.isFileURL))
        }
        .onDropSessionUpdated { session in
            switch session.phase {
            case .entering, .active: isTargeted = true
            default: isTargeted = false
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drop zone")
    }

    private static var radius: CGFloat { 24 }
}

extension DropZone where Accessory == EmptyView {
    init(title: String, subtitle: String, onDrop: @escaping ([URL]) -> Void, onAdd: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, onDrop: onDrop, onAdd: onAdd) { EmptyView() }
    }
}
