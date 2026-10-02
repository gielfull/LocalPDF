import SwiftUI

/// The small "Soon" capsule shown next to tools that aren't implemented yet.
struct SoonBadge: View {
    var body: some View {
        Text("Soon")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: .capsule)
            .accessibilityLabel("Coming soon")
    }
}
