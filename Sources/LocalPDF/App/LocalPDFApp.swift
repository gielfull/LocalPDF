import SwiftUI

@main
struct LocalPDFApp: App {
    @State private var preferences: Preferences
    @State private var queue: JobQueue
    @State private var model: AppModel
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    init() {
        let preferences = Preferences()
        let queue = JobQueue(preferences: preferences)
        _preferences = State(initialValue: preferences)
        _queue = State(initialValue: queue)
        _model = State(initialValue: AppModel(queue: queue, preferences: preferences))
        Task { await JobExecutor.sweepLeftoverWorkingDirectories() }
    }

    /// The main window's scene id, so a Quick Action can reopen it after it was closed.
    static let mainWindowID = "main"

    var body: some Scene {
        WindowGroup(id: Self.mainWindowID) {
            RootView()
                .environment(model)
                .environment(queue)
                .environment(preferences)
                // PDFs and images opened from Finder or the Dock (the app declares both
                // document types) go to the home screen's suggestions; Quick Actions go
                // straight into their tool.
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                .modifier(FinderDelivery(appDelegate: appDelegate, model: model))
        }
        .defaultSize(width: 1200, height: 780)
        .windowResizability(.contentMinSize)
        // The delegate hands opened files to the model. These make SwiftUI reuse the
        // open window for them (or create just one), instead of a window per file.
        .handlesExternalEvents(matching: ["*"])
        .commands {
            AppCommands(model: model)
        }

        Settings {
            SettingsView()
                .environment(preferences)
        }
    }
}

/// Connects the delegate's Finder deliveries to the model once the window exists, and
/// gives the delegate a way to reopen the main window (`openWindow` lives in a view's
/// environment, not the app's).
private struct FinderDelivery: ViewModifier {
    let appDelegate: AppDelegate
    let model: AppModel

    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.task {
            appDelegate.onOpen = { [model] action, urls in model.perform(action, with: urls) }
            appDelegate.showMainWindow = { [openWindow] in openWindow(id: LocalPDFApp.mainWindowID) }
            appDelegate.deliverPending()
        }
    }
}
