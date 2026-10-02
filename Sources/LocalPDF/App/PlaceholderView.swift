import SwiftUI

/// A destination that isn't built yet (Workflows, History).
struct PlaceholderView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
            .navigationTitle(title)
    }
}
