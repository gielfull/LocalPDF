/// Which window a Quick Action brings forward, decided over plain facts about the app's
/// windows so it can be tested without AppKit.
///
/// Only main windows count: SwiftUI names each window of `WindowGroup(id:)` by its scene
/// id, as `<id>-AppWindow-<n>`. The Settings window, panels and sheets have other names,
/// so an open Settings window is never mistaken for the main one.
nonisolated enum MainWindowChoice: Equatable, Sendable {
    /// Bring the window at this index to the front.
    case show(index: Int)
    /// Restore the window at this index from the Dock, then bring it to the front.
    case deminiaturize(index: Int)
    /// No main window is left (the user closed it): open a new one.
    case openNew

    /// The facts about one window that the choice depends on.
    struct Window: Equatable, Sendable {
        var identifier: String?
        var isVisible: Bool
        var isMiniaturized = false
    }

    /// Prefers a visible main window, then a minimized one, and only then a new one.
    static func choose(among windows: [Window], mainWindowID: String) -> MainWindowChoice {
        let main = windows.indices.filter { isMainWindow(windows[$0].identifier, mainWindowID: mainWindowID) }
        if let index = main.first(where: { windows[$0].isVisible }) { return .show(index: index) }
        if let index = main.first(where: { windows[$0].isMiniaturized }) { return .deminiaturize(index: index) }
        return .openNew
    }

    /// True for the windows SwiftUI opens for the scene with `mainWindowID`.
    static func isMainWindow(_ identifier: String?, mainWindowID: String) -> Bool {
        guard let identifier else { return false }
        return identifier == mainWindowID || identifier.hasPrefix("\(mainWindowID)-AppWindow-")
    }
}
