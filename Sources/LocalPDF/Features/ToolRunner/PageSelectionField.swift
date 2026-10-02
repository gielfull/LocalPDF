import PDFEngine
import SwiftUI

/// "All pages / Some pages" plus a range field, bound to an options `PageSelection`
/// (nil means every page).
struct PageSelectionField: View {
    @Binding var selection: PageSelection

    var body: some View {
        Picker("Pages", selection: isAll) {
            Text("All Pages").tag(true)
            Text("Some Pages").tag(false)
        }
        if selection != nil {
            TextField("Page range", text: text, prompt: Text("1-3, 5, 8-"))
        }
    }

    private var isAll: Binding<Bool> {
        Binding(
            get: { selection == nil },
            set: { selection = $0 ? nil : (selection ?? "") }
        )
    }

    private var text: Binding<String> {
        Binding(get: { selection ?? "" }, set: { selection = $0 })
    }
}
