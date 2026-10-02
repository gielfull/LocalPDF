import SwiftUI

/// Asks for a PDF's open password and checks it against the file before accepting.
struct PasswordSheet: View {
    let request: PasswordRequest

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var isRejected: Bool
    @FocusState private var isFocused: Bool

    init(request: PasswordRequest) {
        self.request = request
        _isRejected = State(initialValue: request.wasRejected)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\u{201C}\(request.file.name)\u{201D} is password protected")
                        .font(.headline)
                    Text("Enter its password to use it. The password stays on this Mac and is only used for this file.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit(submit)
                .onChange(of: password) { isRejected = false }
            if isRejected {
                Label("That password is incorrect. Try again.", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Unlock", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear { isFocused = true }
    }

    private func submit() {
        guard !password.isEmpty else { return }
        guard let unlocked = request.file.unlocked(with: password) else {
            isRejected = true
            return
        }
        dismiss()
        request.onSubmit(unlocked)
    }
}
