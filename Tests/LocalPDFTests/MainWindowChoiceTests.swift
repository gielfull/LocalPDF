import Testing
@testable import LocalPDF

@Suite("Quick Action window choice")
struct MainWindowChoiceTests {
    private let id = LocalPDFApp.mainWindowID
    private var settings: MainWindowChoice.Window {
        .init(identifier: "com_apple_SwiftUI_Settings_window", isVisible: true)
    }

    private func main(_ number: Int, visible: Bool, minimized: Bool = false) -> MainWindowChoice.Window {
        .init(identifier: "\(id)-AppWindow-\(number)", isVisible: visible, isMiniaturized: minimized)
    }

    @Test("Only the main scene's windows count as main windows")
    func identifiers() {
        #expect(MainWindowChoice.isMainWindow("\(id)-AppWindow-1", mainWindowID: id))
        #expect(MainWindowChoice.isMainWindow("\(id)-AppWindow-12", mainWindowID: id))
        #expect(MainWindowChoice.isMainWindow(id, mainWindowID: id))
        #expect(!MainWindowChoice.isMainWindow("com_apple_SwiftUI_Settings_window", mainWindowID: id))
        #expect(!MainWindowChoice.isMainWindow("\(id)tenance-AppWindow-1", mainWindowID: id))
        #expect(!MainWindowChoice.isMainWindow(nil, mainWindowID: id))
    }

    @Test("A visible main window is brought forward")
    func visibleMain() {
        #expect(MainWindowChoice.choose(among: [settings, main(1, visible: true)], mainWindowID: id) == .show(index: 1))
    }

    @Test("Settings open, main window closed: open a main window, don't show Settings")
    func settingsOnly() {
        #expect(MainWindowChoice.choose(among: [settings], mainWindowID: id) == .openNew)
    }

    @Test("A minimized main window is restored instead of opening a second one")
    func minimizedMain() {
        let windows = [settings, main(1, visible: false, minimized: true)]
        #expect(MainWindowChoice.choose(among: windows, mainWindowID: id) == .deminiaturize(index: 1))
    }

    @Test("A visible main window wins over a minimized one")
    func visibleBeatsMinimized() {
        let windows = [main(1, visible: false, minimized: true), main(2, visible: true)]
        #expect(MainWindowChoice.choose(among: windows, mainWindowID: id) == .show(index: 1))
    }

    @Test("A closed main window SwiftUI still holds on to doesn't count")
    func closedMain() {
        #expect(MainWindowChoice.choose(among: [main(1, visible: false)], mainWindowID: id) == .openNew)
        #expect(MainWindowChoice.choose(among: [], mainWindowID: id) == .openNew)
    }
}
