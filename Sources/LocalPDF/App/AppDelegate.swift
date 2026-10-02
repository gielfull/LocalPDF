import AppKit

/// Receives files from Finder: "Open With", drags onto the Dock icon, and the app's Quick
/// Actions (Services, see `AppDelegate+Services`). SwiftUI's `onOpenURL` only passes one
/// URL of a multi-file open, so the delegate takes them all.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by `LocalPDFApp` once its model exists.
    var onOpen: ((FinderAction, [URL]) -> Void)?
    /// Set by `LocalPDFApp`: opens a main window when the app is running without one.
    var showMainWindow: (() -> Void)?
    /// Files that arrived before `onOpen` was set (the app was launched by opening them).
    private var pending: [(action: FinderAction, urls: [URL])] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Finder delivers Quick Actions (Services) to this object. Set here rather than
        // later so a Service that launched the app finds its provider.
        NSApp.servicesProvider = self
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        deliver(.open, urls)
        application.activate()
    }

    func deliverPending() {
        guard !pending.isEmpty, let onOpen else { return }
        for delivery in pending {
            onOpen(delivery.action, delivery.urls)
        }
        pending = []
    }

    func deliver(_ action: FinderAction, _ urls: [URL]) {
        if let onOpen {
            onOpen(action, urls)
        } else {
            pending.append((action, urls))
        }
    }

    /// Brings the app forward for a Quick Action: activates it and shows its main window,
    /// restoring it from the Dock or opening one if the user had closed it (Open With gets
    /// this from SwiftUI's `handlesExternalEvents`; a Service doesn't). Which window is
    /// decided by `MainWindowChoice`, so Settings is never taken for the main window.
    func bringMainWindowForward() {
        // A hidden app's windows aren't visible; unhide first so the main window counts
        // as open rather than getting a second one beside it.
        if NSApp.isHidden { NSApp.unhide(nil) }
        NSApp.activate()
        let windows = NSApp.windows
        let facts = windows.map {
            MainWindowChoice.Window(
                identifier: $0.identifier?.rawValue, isVisible: $0.isVisible, isMiniaturized: $0.isMiniaturized
            )
        }
        switch MainWindowChoice.choose(among: facts, mainWindowID: LocalPDFApp.mainWindowID) {
        case .show(let index):
            windows[index].makeKeyAndOrderFront(nil)
        case .deminiaturize(let index):
            windows[index].deminiaturize(nil)
            windows[index].makeKeyAndOrderFront(nil)
        case .openNew:
            showMainWindow?()
        }
    }
}
