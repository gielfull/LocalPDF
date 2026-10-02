import SwiftUI

/// Protect PDF's inspector section: the open password, then optional permissions.
struct ProtectOptions: View {
    @Bindable var session: ToolSession

    var body: some View {
        Section {
            SecureField("Password", text: $session.protect.userPassword, prompt: Text("Required"))
            SecureField("Confirm", text: $session.protectConfirmation, prompt: Text("Type it again"))
        } header: {
            Text("Password to Open")
        } footer: {
            Text("Anyone opening the PDF will need this password. LocalPDF can't recover it for you.")
        }
        Section {
            Toggle("Allow printing", isOn: $session.protect.allowPrinting)
            Toggle("Allow copying text and images", isOn: $session.protect.allowCopying)
            Toggle("Allow editing", isOn: $session.protect.allowEditing)
            SecureField("Permissions password", text: ownerPassword, prompt: Text("Same as above"))
        } header: {
            Text("Permissions")
        } footer: {
            Text("Needed to change these permissions later.")
        }
    }

    private var ownerPassword: Binding<String> {
        Binding(
            get: { session.protect.ownerPassword ?? "" },
            set: { session.protect.ownerPassword = $0.isEmpty ? nil : $0 }
        )
    }
}
