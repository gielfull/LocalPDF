import SwiftUI

/// A calm note in the result sheet that the saved copy lost the original's password or
/// restrictions, with a prominent button to protect it again.
struct ProtectionDroppedCard: View {
    let message: String
    let actionTitle: String
    let actionImage: String
    let tint: Color
    let onProtect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.open")
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(actionTitle, systemImage: actionImage, action: onProtect)
                .buttonStyle(.glassProminent)
                .tint(tint)
                .controlSize(.large)
                .fixedSize()
        }
        .padding(14)
        .background(.fill.quinary, in: .rect(cornerRadius: 12))
    }
}
